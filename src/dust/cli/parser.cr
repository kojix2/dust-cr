require "option_parser"

require "./options"

module Dust
  module CLI
    VERSION = "1.2.6"

    BANNER = <<-TEXT
      Usage: dust [OPTIONS] [PATH]...

      A more intuitive version of du.
      TEXT

    class Parser
      @options = Options.new

      def initialize(@output : IO = STDOUT, @error : IO = STDERR)
      end

      def parse(argv : Array(String)) : Options
        @options = Options.new
        args = argv.dup

        build_parser.parse(args)
        validate_conflicts
        @options
      end

      private def build_parser : OptionParser
        OptionParser.new do |parser|
          parser.banner = BANNER
          register_numbers(parser)
          register_walk(parser)
          register_display(parser)
          register_filters(parser)
          register_input(parser)
          register_output(parser)
          register_meta(parser)
          register_handlers(parser)
        end
      end

      private def register_numbers(parser : OptionParser) : Nil
        parser.on("-d DEPTH", "--depth=DEPTH", "Depth to show") do |value|
          @options.depth = parse_number("depth", value)
        end
        parser.on("-T THREADS", "--threads=THREADS", "Number of threads to use") do |value|
          @options.threads = parse_number("threads", value).to_i32
        end
        parser.on("-n NUMBER", "--number-of-lines=NUMBER", "Display the 'n' largest entries") do |value|
          @options.lines = parse_number("number-of-lines", value).to_i32
        end
        parser.on("-w WIDTH", "--terminal-width=WIDTH", "Set the output width") do |value|
          @options.terminal_width = parse_number("terminal-width", value).to_i32
        end
      end

      private def register_walk(parser : OptionParser) : Nil
        parser.on("-p", "--full-paths", "Do not shorten subdirectory paths") do
          @options.full_paths = true
        end
        parser.on("-X PATH", "--ignore-directory=PATH", "Exclude a file or directory with this path") do |value|
          @options.ignore_directory << value
        end
        parser.on("-L", "--dereference-links", "Treat symbolic links as directories") do
          @options.dereference_links = true
        end
        parser.on("-x", "--limit-filesystem", "Only count files on the target filesystem") do
          @options.limit_filesystem = true
        end
        parser.on("-s", "--apparent-size", "Use file length instead of disk usage") do
          @options.apparent_size = true
        end
        parser.on("-f", "--filecount", "Count child files instead of disk usage") do
          @options.filecount = true
        end
        parser.on("-i", "--ignore-hidden", "Do not display hidden files") do
          @options.ignore_hidden = true
        end
        parser.on("-P", "--no-progress", "Disable progress indication") { }
      end

      private def register_display(parser : OptionParser) : Nil
        parser.on("-r", "--reverse", "Print the tree upside down") { @options.reverse = true }
        parser.on("-b", "--no-percent-bars", "Do not display percent bars or percentages") do
          @options.hide_bars = true
        end
        parser.on("-B", "--bars-on-right", "Move percent bars to the right") do
          @options.right_bars = true
        end
        parser.on("--dim", "Dim the percent bars") { @options.dim = true }
        parser.on("-R", "--screen-reader", "Remove bars and add a depth column") do
          @options.screen_reader = true
        end
        parser.on("--skip-total", "Do not display the total row") { @options.skip_total = true }
        parser.on("-D", "--only-dir", "Only display directories") { @options.only_dir = true }
        parser.on("-F", "--only-file", "Only display files") { @options.only_file = true }
      end

      private def register_filters(parser : OptionParser) : Nil
        parser.on("-z SIZE", "--min-size=SIZE", "Minimum size to include (for example 10M)") do |value|
          @options.min_size = value
        end
        parser.on("-v REGEX", "--invert-filter=REGEX", "Exclude paths matching this regular expression") do |value|
          @options.invert_filter << compile_regex(value)
        end
        parser.on("-e REGEX", "--filter=REGEX", "Only include paths matching this regular expression") do |value|
          @options.filter << compile_regex(value)
        end
      end

      private def register_input(parser : OptionParser) : Nil
        parser.on("--files0-from=FILE", "Read NUL-terminated paths from FILE ('-' for stdin)") do |value|
          @options.files0_from = value
        end
        parser.on("--files-from=FILE", "Read newline-terminated paths from FILE ('-' for stdin)") do |value|
          @options.files_from = value
        end
        parser.on("--collapse=DIR", "Keep this directory collapsed") do |value|
          @options.collapse << value
        end
      end

      private def register_output(parser : OptionParser) : Nil
        parser.on("-c", "--no-colors", "Do not print colors") { @options.no_colors = true }
        parser.on("-C", "--force-colors", "Force colors") { @options.force_colors = true }
        parser.on("--print-errors", "Print paths that could not be read") do
          @options.print_errors = true
        end
        parser.on("-o FORMAT", "--output-format=FORMAT", "Output size format") do |value|
          @options.output_format = parse_format(value)
        end
        parser.on("-j", "--output-json", "Output the directory tree as JSON") do
          @options.output_json = true
        end
      end

      private def register_meta(parser : OptionParser) : Nil
        parser.on("-h", "--help", "Print help") do
          @output.puts parser
          exit 0
        end
        parser.on("-V", "--version", "Print version") do
          @output.puts "Dust #{VERSION}"
          exit 0
        end
      end

      private def register_handlers(parser : OptionParser) : Nil
        parser.unknown_args do |before_dash, after_dash|
          @options.params.concat(before_dash)
          @options.params.concat(after_dash)
        end
        parser.invalid_option do |flag|
          fail_with("unexpected argument '#{flag}' found")
        end
        parser.missing_option do |flag|
          long = long_name(flag)
          fail_with("a value is required for '--#{long} <#{placeholder(long)}>' but none was supplied")
        end
      end

      # PCRE2 reports syntax errors as Regex::Error or as a plain ArgumentError.
      private def compile_regex(value : String) : Regex
        Regex.new(value)
      rescue ex : Regex::Error | ArgumentError
        @error.puts "Ignoring bad value for regex #{value.inspect}: #{ex.message}"
        exit 1
      end

      private def parse_number(long : String, value : String) : Int64
        flag = "'--#{long} <#{placeholder(long)}>'"
        number = value.to_i64?
        unless number
          fail_with("invalid value '#{value}' for #{flag}: invalid digit found in string", usage: false)
        end
        if number < 0
          fail_with("invalid value '#{value}' for #{flag}: number too large to fit in target type", usage: false)
        end
        number
      end

      private def parse_format(value : String) : String
        format = value.downcase
        unless OUTPUT_FORMATS.includes?(format)
          fail_with("invalid value '#{value}' for '--output-format <FORMAT>'",
            %w[si b k m g t kb mb gb tb], usage: false)
        end
        format
      end

      private def validate_conflicts : Nil
        if @options.only_dir? && @options.only_file?
          fail_with("the argument '--only-dir' cannot be used with '--only-file'")
        end
        if @options.only_dir? && !@options.filter.empty?
          fail_with("the argument '--only-dir' cannot be used with '--filter <REGEX>'")
        end
        if !@options.invert_filter.empty? && !@options.filter.empty?
          fail_with("the argument '--invert-filter <REGEX>' cannot be used with '--filter <REGEX>'")
        end
        if @options.files_from && @options.files0_from
          fail_with("the argument '--files-from <FILE>' cannot be used with '--files0-from <FILE>'")
        end
      end

      private def long_name(flag : String) : String
        case flag
        when "-d" then "depth"
        when "-T" then "threads"
        when "-n" then "number-of-lines"
        when "-X" then "ignore-directory"
        when "-z" then "min-size"
        when "-v" then "invert-filter"
        when "-e" then "filter"
        when "-w" then "terminal-width"
        when "-o" then "output-format"
        else           flag.lchop("--")
        end
      end

      private def placeholder(long : String) : String
        case long
        when "depth"                     then "DEPTH"
        when "threads"                   then "THREADS"
        when "number-of-lines"           then "NUMBER"
        when "ignore-directory"          then "PATH"
        when "min-size"                  then "SIZE"
        when "invert-filter", "filter"   then "REGEX"
        when "terminal-width"            then "WIDTH"
        when "output-format"             then "FORMAT"
        when "files0-from", "files-from" then "FILE"
        when "collapse"                  then "DIR"
        else                                  long.upcase
        end
      end

      private def fail_with(message : String, possible_values : Array(String)? = nil,
                            usage : Bool = true) : NoReturn
        @error.puts "error: #{message}"
        @error.puts "  [possible values: #{possible_values.join(", ")}]" if possible_values
        @error.puts
        if usage
          @error.puts "Usage: dust [OPTIONS] [PATH]..."
          @error.puts
        end
        @error.puts "For more information, try '--help'."
        exit 2
      end
    end
  end
end
