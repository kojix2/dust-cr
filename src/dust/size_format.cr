module Dust
  # Size and min-size formatting, ported from `display.rs` and `config.rs`.
  module SizeFormat
    extend self

    SI_UNITS  = %w[P T G M K]
    IEC_UNITS = %w[Pi Ti Gi Mi Ki]

    # Are we working in powers of 1000 or 1024?
    def base(format : String) : UInt64
      if format.empty? || format == "si"
        format.empty? ? 1024_u64 : 1000_u64
      elsif format.includes?('i') || format.size == 1
        1024_u64
      else
        1000_u64
      end
    end

    def units(format : String) : Array(String)
      base(format) == 1024 ? IEC_UNITS : SI_UNITS
    end

    # A forced output unit (`-o kib`, `-o b`, ...) as {multiplier, suffix}.
    def number_format(format : String) : {UInt64, String}?
      return {1_u64, "B"} if format.starts_with?('b')

      list = units(format)
      list.each_with_index do |unit, index|
        first = unit[0].downcase
        if format.starts_with?(first)
          thousand = base(format)
          marker = thousand ** (list.size - index)
          return {marker, unit}
        end
      end

      nil
    end

    def humanize(size : UInt64, format : String) : String
      return size.to_s if format == "count"

      if fixed = number_format(format)
        divisor, unit = fixed
        return "#{size // divisor}#{unit}"
      end

      list = units(format)
      thousand = base(format)

      list.each_with_index do |unit, index|
        marker = thousand ** (list.size - index)
        next unless size >= marker

        if size // marker < 10
          return "#{sprintf("%.1f", size.to_f64 / marker)}#{unit}"
        else
          return "#{size // marker}#{unit}"
        end
      end

      "#{size}B"
    end

    # Parses `--min-size`. Accepts bare bytes and any SI/IEC suffix, case
    # insensitively. Returns nil (after warning) for anything else.
    def parse_min(input : String) : UInt64?
      match = /([0-9]+)(\w*)/.match(input)
      unless match
        STDERR.puts "Ignoring invalid min-size: #{input}"
        return
      end

      size = match[1].to_u64?
      unless size
        STDERR.puts "Ignoring invalid min-size: #{input}"
        return
      end

      suffix = match[2].downcase
      return size if suffix.empty?

      if format = number_format(suffix)
        divisor, _unit = format
        return size * divisor
      end

      STDERR.puts "Ignoring invalid min-size: #{input}"
      nil
    end
  end
end
