require "wait_group"

require "./node"
require "./platform"
require "./utils"
require "./walker/directory_queue"
require "./walker/runtime_errors"

module Dust
  class Walker
    @errors : Errors
    @absolute : Array(String)? = nil
    # Signalled once a root directory and all of its children are built.
    @root_done : Channel(Nil)? = nil

    def initialize(@apparent : Bool = false, @count_files : Bool = false,
                   @hide_hidden : Bool = false, @follow_links : Bool = false,
                   @ignored : Set(String) = Set(String).new,
                   @filters : Array(Regex) = [] of Regex,
                   @excludes : Array(Regex) = [] of Regex,
                   @filesystems : Set(UInt64) = Set(UInt64).new,
                   error : IO = STDERR)
      @errors = Errors.new(error)
    end

    def errors : Errors
      @errors
    end

    # Walks every root in turn and returns the deduplicated top level nodes.
    def walk(dirs : Set(String), threads : Int32) : Array(Node)
      inodes = Set(FileId).new
      roots = [] of Node

      dirs.each do |dir|
        root_link = false
        if @follow_links
          if stat = Platform.lstat(dir)
            root_link = Platform.kind_of(stat) == FileKind::Symlink
          end
        end

        root = WalkerSupport::Pending.new(dir, 0, root_link)
        run_pool(root, threads)

        if root_node = root.own_node
          if cleaned = clean_inodes(root_node, inodes)
            roots << cleaned
          end
        end
      end

      roots
    end

    # Runs `workers` workers over one queue until the whole tree is built.
    #
    # No worker ever waits for a child directory: children hand their finished
    # node to the parent, and the parent is only built once every child has
    # reported in. So workers can never block on each other, and the walk ends
    # when the root's node is ready.
    private def run_pool(root : WalkerSupport::Pending, workers : Int32) : Nil
      queue = WalkerSupport::Queue.new
      done = WaitGroup.new(workers)
      root_done = Channel(Nil).new(1)
      @root_done = root_done

      context = Fiber::ExecutionContext.current
      workers.times do
        context.spawn do
          while item = queue.pop
            walk_dir(item, queue)
          end
        ensure
          done.done
        end
      end

      queue.push(root)
      # Waiting for the root's *node*, not for its listing: the rest of the
      # subtree is still being walked at this point.
      root_done.receive

      # Closing the queue lets the workers return.
      queue.close
      done.wait
      @root_done = nil
    end

    private def walk_dir(pending : WalkerSupport::Pending,
                         queue : WalkerSupport::Queue) : Nil
      entries, invalid = list_dir(pending.dir)

      if entries
        children = Array(Node).new(entries.size)
        subdirs = [] of WalkerSupport::Pending

        entries.each do |name|
          path = Utils.join(pending.dir, name)
          next if ignore_entry?(path, name)

          stat = Platform.lstat(path)
          next unless stat

          kind = Platform.kind_of(stat)
          is_symlink = kind == FileKind::Symlink

          if kind == FileKind::Directory || (@follow_links && is_symlink)
            subdirs << WalkerSupport::Pending.new(path, pending.depth + 1,
              is_symlink, pending)
            next
          end

          if node = build_node(path, nil, is_symlink, kind == FileKind::File, pending.depth, stat)
            children << node
          end
        end

        # Count the subdirectories before queueing them, so a fast worker cannot
        # complete this directory while children are still missing.
        pending.prepare(children, subdirs.size)
        subdirs.each { |subdir| queue.push(subdir) }
      elsif invalid
        errors.add_missing(pending.dir)
      end

      # Without subdirectories the directory is already complete.
      deliver(pending) if pending.listed?
    end

    # Builds the node of a finished directory and hands it to its parent. If it
    # was the last subdirectory outstanding the parent is finished too, so its
    # node is built and handed on in turn: the walk never recurses, no matter how
    # deep the tree is. A directory without a parent is a root, which ends the
    # walk of that target.
    private def deliver(finished : WalkerSupport::Pending) : Nil
      node = build_node(finished.dir, finished.done_children, finished.symlink?, false,
        finished.depth)
      finished.own_node = node if node

      current = finished.parent
      while parent = current
        return unless parent.child_finished(node)

        node = build_node(parent.dir, parent.done_children, parent.symlink?, false, parent.depth)
        parent.own_node = node if node
        current = parent.parent
      end

      finish
    end

    private def finish : Nil
      @root_done.try(&.send(nil))
    end

    # Lists a directory, returning {entry names, invalid path}:
    #
    #  * a plain file counts as an empty directory (dust shows the file itself)
    #  * anything that is not a directory at all (missing path, socket, ...) is
    #    reported as invalid for the caller to record
    #  * a failed listing returns nil names, the error having been recorded here
    private def list_dir(dir : String) : {Array(String)?, Bool}
      kind = Platform.stat(dir).try { |stat| Platform.kind_of(stat) }
      return {[] of String, false} if kind == FileKind::File
      return {nil, true} unless kind == FileKind::Directory

      loop do
        return {Dir.children(dir), false}
      rescue ex : File::Error
        errors.record(ex, dir)
        # EINTR is the only retryable error.
        retryable = ex.os_error == Errno::EINTR
        return {nil, false} unless retryable && errors.interrupted < 999
      end
    end

    private def ignore_entry?(path : String, name : String) : Bool
      return true if @ignored.includes?(path)
      return true if hidden_path?(path)
      return true if @hide_hidden && name.starts_with?('.')
      return true if foreign_fs?(path)
      return true if rejected?(path)

      false
    end

    # With -x only the filesystems of the target directories are walked, which
    # prunes whole directories rather than just files.
    private def foreign_fs?(path : String) : Bool
      return false if @filesystems.empty?

      is_symlink = false
      if @follow_links && (stat = Platform.lstat(path))
        is_symlink = Platform.kind_of(stat) == FileKind::Symlink
      end

      if device = Platform.device_of(path, is_symlink)
        return !@filesystems.includes?(device)
      end

      false
    end

    # Regex filters only apply to files (`Path::is_file` follows symlinks).
    private def rejected?(path : String) : Bool
      return false if @filters.empty? && @excludes.empty?
      return false unless File.file?(path)

      Utils.unmatched?(@filters, path) || Utils.excluded?(@excludes, path)
    end

    # Entries below an absolute ignore path. Only absolute ignores are kept in
    # the list, so the common case costs nothing.
    private def hidden_path?(path : String) : Bool
      absolute_paths.each do |ignored|
        absolute = begin
          File.realpath(path)
        rescue
          ""
        end
        return true if absolute.starts_with?(ignored)
      end

      false
    end

    private def absolute_paths : Array(String)
      @absolute ||= @ignored.to_a.select { |path| Utils.absolute?(path) }
    end

    # `stat` is the lstat the caller already performed, when it has one: stat'ing
    # every entry twice would double the syscalls of the whole walk.
    private def build_node(path : String, children : Array(Node)?, is_symlink : Bool,
                           is_file : Bool, depth : Int32, stat : LibC::Stat? = nil) : Node?
      follow = @follow_links && is_symlink
      metadata = if stat && !follow
                   Platform.metadata_from(stat, @apparent)
                 else
                   Platform.get_metadata(path, @apparent, follow)
                 end
      return unless metadata

      size = if filtered_out?(path) || (@count_files && !is_file)
               0_u64
             elsif @count_files
               1_u64
             else
               metadata.size
             end

      # Ordinary files with one link cannot be hard-link duplicates. Following
      # symlinks is the exception: aliases can reach an inode with one link.
      file_id = if !@apparent && (@follow_links || metadata.links > 1)
                  metadata.inode_device
                end
      Node.new(path, size, children, file_id, depth)
    end

    # Applied in `build_node`, where a filtered out entry keeps its place in the
    # tree but contributes nothing.
    private def filtered_out?(path : String) : Bool
      Utils.unmatched?(@filters, path) || Utils.excluded?(@excludes, path)
    end

    # Removes entries sharing an inode with something already counted, so hard
    # links are not counted twice. Runs after the walk, on one thread.
    private def clean_inodes(node : Node, inodes : Set(FileId)) : Node?
      # `add?` rather than `add`: `Set#add` returns the set, not a Bool.
      if !@apparent && (id = node.inode_device) && !inodes.add?(id)
        return
      end

      # Sorting by inode makes the choice of surviving hard link predictable.
      # Reuse the walked tree: rebuilding it here used to double its live size.
      children = node.children
      unless children.empty?
        children.sort! { |left, right| inode_order(left, right) }
        children.select! { |child| clean_inodes(child, inodes) }
      end
      node.total!
      node
    end

    private def inode_order(left : Node, right : Node) : Int32
      left_id = left.inode_device
      right_id = right.inode_device

      if left_id && right_id
        order = left_id[0] <=> right_id[0]
        order == 0 ? left.name <=> right.name : order
      elsif left_id
        1
      elsif right_id
        -1
      else
        left.name <=> right.name
      end
    end
  end
end
