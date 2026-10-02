require "fiber"

require "./cli/options"
require "./dir_walker"
require "./display_node"
require "./filter"
require "./size_format"
require "./term"
require "./utils"

module Dust
  record ScanResult, tree : DisplayNode, errors : Errors

  # Turns CLI options and target paths into a filtered display tree.
  class Scanner
    def initialize(@options : CLI::Options, @error : IO = STDERR)
    end

    def call(target_dirs : Array(String)) : ScanResult
      simplified_dirs = Utils.simplify(target_dirs)
      walker = build_walker(target_dirs, simplified_dirs)
      nodes = walker.walk(simplified_dirs, worker_count)
      filter = Pruner.new(filter_options, collapsed_paths(target_dirs))

      ScanResult.new(filter.call(nodes), walker.errors)
    end

    private def build_walker(target_dirs : Array(String),
                             simplified_dirs : Set(String)) : Walker
      Walker.new(
        apparent: @options.apparent_size?,
        count_files: @options.filecount?,
        hide_hidden: @options.ignore_hidden?,
        follow_links: @options.dereference_links?,
        ignored: ignored_paths(simplified_dirs),
        filters: @options.filter,
        excludes: @options.invert_filter,
        filesystems: allowed_filesystems(target_dirs),
        error: @error
      )
    end

    # Ignored paths are matched per target directory, so `-X many` below `src`
    # ignores `src/many`.
    private def ignored_paths(target_dirs : Set(String)) : Set(String)
      @options.ignore_directory.each_with_object(Set(String).new) do |dir, ignored|
        canonical = Utils.canonical(dir)
        target_dirs.each { |target| ignored.add(Utils.join(target, canonical)) }
      end
    end

    private def collapsed_paths(target_dirs : Array(String)) : Set(String)
      @options.collapse.each_with_object(Set(String).new) do |dir, collapsed|
        target_dirs.each { |target| collapsed.add(Utils.join(target, dir)) }
      end
    end

    private def allowed_filesystems(target_dirs : Array(String)) : Set(UInt64)
      return Set(UInt64).new unless @options.limit_filesystem?

      Utils.devices(target_dirs, @options.dereference_links?)
    end

    private def worker_count : Int32
      workers = @options.threads || Fiber::ExecutionContext.default_workers_count
      workers = 1 if workers < 1
      Fiber::ExecutionContext.default.resize(workers) if workers > 1
      workers
    end

    private def filter_options : Pruner::Options
      Pruner::Options.new(
        min_size: @options.min_size.try { |value| SizeFormat.parse_min(value) },
        only_dir: @options.only_dir?,
        only_file: @options.only_file?,
        lines: line_count,
        depth: @options.depth,
        filtered: @options.filtered?,
        short_paths: !@options.full_paths?
      )
    end

    private def line_count : Int64
      if requested = @options.lines
        return requested.to_i64
      end

      if @options.depth != CLI::UNLIMITED_DEPTH || @options.output_json?
        Int64::MAX
      else
        Term.height.to_i64
      end
    end
  end
end
