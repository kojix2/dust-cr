module Dust
  module Display
    module Text
      def self.printable_name(path : String, short_paths : Bool) : String
        return path unless short_paths

        if index = path.rindex('/')
          basename = path[(index + 1)..]
          basename.empty? ? path : basename
        else
          path
        end
      end

      def self.commas(value : UInt64) : String
        digits = value.to_s
        return digits if digits.size <= 3

        head_size = digits.size % 3
        head_size = 3 if head_size == 0
        head = digits[0, head_size]
        rest = digits[head_size..]
        "#{head},#{rest.scan(/.{1,3}/).join(',')}"
      end
    end
  end
end
