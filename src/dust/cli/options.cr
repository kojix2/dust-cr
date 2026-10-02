module Dust
  module CLI
    OUTPUT_FORMATS = %w[si b k kib m mib g gib t tib kb mb gb tb]

    # `usize::MAX` in the original; used as "no depth limit".
    UNLIMITED_DEPTH = Int64::MAX

    class Options
      property depth : Int64 = UNLIMITED_DEPTH
      property threads : Int32?
      property lines : Int32?
      property? full_paths = false
      property ignore_directory = [] of String
      property? dereference_links = false
      property? limit_filesystem = false
      property? apparent_size = false
      property? reverse = false
      property? no_colors = false
      property? force_colors = false
      property? dim = false
      property? hide_bars = false
      property? right_bars = false
      property min_size : String?
      property? screen_reader = false
      property? skip_total = false
      property? filecount = false
      property? ignore_hidden = false
      property invert_filter = [] of Regex
      property filter = [] of Regex
      property terminal_width : Int32?
      property? print_errors = false
      property? only_dir = false
      property? only_file = false
      property output_format : String? = nil
      property? output_json = false
      property files0_from : String? = nil
      property files_from : String? = nil
      property collapse = [] of String
      property params = [] of String

      def format_name : String
        output_format || ""
      end

      def filtered? : Bool
        !filter.empty? || !invert_filter.empty?
      end
    end
  end
end
