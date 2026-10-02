module Dust
  module Utils
    extend self

    # Mirrors `Path::components().collect()`: drops repeated separators, `.`
    # components and trailing separators. `..` is kept, as Rust keeps it.
    def normalize(path : String) : String
      absolute = path.starts_with?('/')
      parts = path.split('/').reject { |part| part.empty? || part == "." }
      body = parts.join('/')
      if absolute
        body.empty? ? "/" : "/#{body}"
      elsif body.empty? && !path.empty?
        "."
      else
        body
      end
    end

    def absolute?(path : String) : Bool
      path.starts_with?('/')
    end

    # `Path::join`: an absolute child replaces the parent entirely, an empty
    # child leaves the parent untouched.
    def join(dir : String, child : String) : String
      return child if absolute?(child)
      return dir if child.empty?
      return child if dir.empty?

      dir.ends_with?('/') ? "#{dir}#{child}" : "#{dir}/#{child}"
    end

    # `parent` is a strict ancestor of `child`. Both paths are normalized first,
    # so "/usr" is not treated as the parent of "/usr/.".
    def parent?(parent : String, child : String) : Bool
      parent = normalize(parent)
      child = normalize(child)
      return false if parent == child
      return true if parent == "/"
      return false unless child.size > parent.size

      child.starts_with?(parent) &&
        (parent.ends_with?('/') || child[parent.size] == '/')
    end

    # Removes directories that are already covered by another entry, so that
    # `dust a/b a/b/c` only walks `a/b`.
    def simplify(dirs : Array(String)) : Set(String)
      roots = Set(String).new

      dirs.each do |dir|
        root = normalize(dir)
        can_add = true
        to_remove = [] of String

        roots.each do |existing|
          if parent?(root, existing)
            to_remove << existing
          elsif parent?(existing, root)
            can_add = false
          end
        end

        to_remove.each { |path| roots.delete(path) }
        roots.add(root) if can_add
      end

      roots
    end

    def canonical(path : String) : String
      return path unless absolute?(path)
      File.realpath(path) rescue path
    end

    def devices(paths : Array(String), follow_links : Bool) : Set(UInt64)
      devices = Set(UInt64).new

      paths.each do |path|
        follow = false
        if follow_links
          if stat = Platform.lstat(path)
            follow = Platform.kind_of(stat) == FileKind::Symlink
          end
        end
        if device = Platform.device_of(path, follow)
          devices.add(device)
        end
      end

      devices
    end

    def unmatched?(filters : Array(Regex), path : String) : Bool
      return false if filters.empty?

      filters.all? { |regex| !regex.matches?(path) }
    end

    def excluded?(filters : Array(Regex), path : String) : Bool
      filters.any?(&.matches?(path))
    end
  end
end
