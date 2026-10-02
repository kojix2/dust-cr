module Dust
  # Thread-safe collection of filesystem errors encountered during a walk.
  class Errors
    getter denied = Set(String).new
    getter missing = Set(String).new
    getter unknown = Set(String).new
    property interrupted : Int32 = 0

    @mutex = Thread::Mutex.new

    def initialize(@error : IO = STDERR)
    end

    def record(failed : Exception, dir : String) : Nil
      message = failed.message || failed.class.name
      errno = failed.is_a?(File::Error) ? failed.as(File::Error).os_error : nil

      @mutex.synchronize do
        case errno
        when Errno::EACCES, Errno::EPERM, Errno::EINVAL
          @denied.add(dir)
        when Errno::ENOENT
          @missing.add(message)
        when Errno::EINTR
          @interrupted += 1
          if @interrupted > 999
            @error.puts "Too many Interrupted Errors occurred while scanning filesystem, skipping: #{dir}"
          end
        else
          @unknown.add(message)
        end
      end
    end

    def add_missing(path : String) : Nil
      @mutex.synchronize { @missing.add(path) }
    end
  end

  class Reporter
    def initialize(@output : IO = STDERR)
    end

    def report(errors : Errors, verbose : Bool) : Nil
      unless errors.missing.empty?
        @output.puts "No such file or directory: #{errors.missing.to_a.join(", ")}"
      end

      unless errors.denied.empty?
        if verbose
          @output.puts "Did not have permissions for directories: #{errors.denied.to_a.join(", ")}"
        else
          @output.puts "Did not have permissions for all directories (add --print-errors to see errors)"
        end
      end

      unless errors.unknown.empty?
        @output.puts "Unknown Error: #{errors.unknown.to_a.join(", ")}"
      end
    end
  end
end
