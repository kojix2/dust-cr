require "./cli/options"

module Dust
  # Resolves positional arguments and the two file-list options into scan roots.
  class Inputs
    def initialize(@options : CLI::Options, @input : IO = STDIN, @error : IO = STDERR)
    end

    def resolve : Array(String)
      paths = if source = @options.files0_from
                read_source(source, null_terminated: true)
              elsif source = @options.files_from
                read_source(source, null_terminated: false)
              else
                @options.params.empty? ? ["."] : @options.params
              end

      paths.reject(&.empty?)
    end

    private def read_source(path : String, *, null_terminated : Bool) : Array(String)
      from_stdin = path == "-"
      content = from_stdin ? @input.gets_to_end : read_file(path)
      paths = null_terminated ? content.split('\0').reject(&.empty?) : content.lines(chomp: true)

      if from_stdin && paths.empty?
        @error.puts "No files provided, defaulting to current directory"
        return ["."]
      end

      paths
    end

    private def read_file(path : String) : String
      File.read(path)
    rescue ex : File::Error
      @error.puts "Failed to read file: #{ex.message}"
      "."
    end
  end
end
