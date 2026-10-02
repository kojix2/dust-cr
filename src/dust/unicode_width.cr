module Dust
  # Display width of a string in terminal columns.
  #
  # Not a full port of the `unicode-width` crate: the ranges below cover the
  # East Asian Wide/Fullwidth blocks and the emoji blocks, which is what dust's
  # alignment actually needs, plus the zero width combining marks.
  module UnicodeWidth
    extend self

    WIDE_RANGES = [
      {0x1100, 0x115F},
      {0x2E80, 0x303E},
      {0x3041, 0x33FF},
      {0x3400, 0x4DBF},
      {0x4E00, 0x9FFF},
      {0xA000, 0xA4CF},
      {0xA960, 0xA97F},
      {0xAC00, 0xD7A3},
      {0xF900, 0xFAFF},
      {0xFE10, 0xFE19},
      {0xFE30, 0xFE6F},
      {0xFF00, 0xFF60},
      {0xFFE0, 0xFFE6},
      {0x17000, 0x187F7},
      {0x1B000, 0x1B2FF},
      {0x1F004, 0x1F004},
      {0x1F0CF, 0x1F0CF},
      {0x1F18E, 0x1F18E},
      {0x1F191, 0x1F19A},
      {0x1F200, 0x1F320},
      {0x1F32D, 0x1F335},
      {0x1F337, 0x1F37C},
      {0x1F37E, 0x1F393},
      {0x1F3A0, 0x1F3CA},
      {0x1F3CF, 0x1F3D3},
      {0x1F3E0, 0x1F3F0},
      {0x1F3F4, 0x1F3F4},
      {0x1F3F8, 0x1F43E},
      {0x1F440, 0x1F440},
      {0x1F442, 0x1F4FC},
      {0x1F4FF, 0x1F53D},
      {0x1F54B, 0x1F54E},
      {0x1F550, 0x1F567},
      {0x1F57A, 0x1F57A},
      {0x1F595, 0x1F596},
      {0x1F5A4, 0x1F5A4},
      {0x1F5FB, 0x1F64F},
      {0x1F680, 0x1F6C5},
      {0x1F6CC, 0x1F6CC},
      {0x1F6D0, 0x1F6D2},
      {0x1F6D5, 0x1F6D7},
      {0x1F6DD, 0x1F6DF},
      {0x1F6EB, 0x1F6EC},
      {0x1F6F4, 0x1F6FC},
      {0x1F7E0, 0x1F7EB},
      {0x1F7F0, 0x1F7F0},
      {0x1F90C, 0x1F93A},
      {0x1F93C, 0x1F945},
      {0x1F947, 0x1F9FF},
      {0x1FA70, 0x1FAFF},
      {0x20000, 0x2FFFD},
      {0x30000, 0x3FFFD},
    ] of Tuple(Int32, Int32)

    ZERO_RANGES = [
      {0x0300, 0x036F},
      {0x0483, 0x0489},
      {0x0591, 0x05BD},
      {0x0610, 0x061A},
      {0x064B, 0x065F},
      {0x06D6, 0x06DC},
      {0x0E31, 0x0E31},
      {0x0E34, 0x0E3A},
      {0x0E47, 0x0E4E},
      {0x200B, 0x200F},
      {0x2028, 0x202E},
      {0x20D0, 0x20F0},
      {0x20E3, 0x20E3},
      {0xFE00, 0xFE0F},
      {0xFE20, 0xFE2F},
      {0xFEFF, 0xFEFF},
      {0x1AB0, 0x1AFF},
      {0x1DC0, 0x1DFF},
      {0xE0100, 0xE01EF},
    ] of Tuple(Int32, Int32)

    # Symbols that take an emoji presentation with U+FE0F. Anything outside
    # these blocks is left alone by the variation selector.
    EMOJI_BASES = [
      {0x0023, 0x0023},
      {0x002A, 0x002A},
      {0x0030, 0x0039},
      {0x00A9, 0x00A9},
      {0x00AE, 0x00AE},
      {0x203C, 0x203C},
      {0x2049, 0x2049},
      {0x2122, 0x2122},
      {0x2139, 0x2139},
      {0x2190, 0x21FF},
      {0x2300, 0x23FF},
      {0x2460, 0x24FF},
      {0x25A0, 0x27BF},
      {0x2934, 0x2935},
      {0x2B00, 0x2BFF},
      {0x3030, 0x3030},
      {0x303D, 0x303D},
      {0x3297, 0x3297},
      {0x3299, 0x3299},
    ] of Tuple(Int32, Int32)

    JOINER = 0x200D
    # U+FE0F asks for the emoji (two column) presentation of the symbol before it.
    VARIATION_16 = 0xFE0F

    def char_width(char : Char) : Int32
      codepoint = char.ord
      return 0 if codepoint < 0x20 || (0x7F <= codepoint < 0xA0)
      return 0 if in_ranges?(codepoint, ZERO_RANGES)
      return 2 if in_ranges?(codepoint, WIDE_RANGES)

      1
    end

    # Yields each display cluster: its characters and how many columns it takes.
    # Emoji joined with a zero width joiner (`👩‍💻`) render as one two column
    # cluster rather than as three separate glyphs.
    def each_cluster(string : String, & : (Array(Char), Int32) ->)
      chars = string.chars
      index = 0

      while index < chars.size
        start = index
        width = char_width(chars[index])
        index += 1

        # Emoji presentation: a symbol followed by U+FE0F is drawn two columns
        # wide even when its default presentation is narrow.
        if width == 1 && emoji_base?(chars[index - 1]) && index < chars.size &&
           chars[index].ord == VARIATION_16
          index += 1
          width = 2
        end

        while index + 1 < chars.size && chars[index].ord == JOINER &&
              char_width(chars[index + 1]) == 2
          index += 2
          width = 2
        end

        yield chars[start...index], width
      end
    end

    def width(string : String) : Int32
      total = 0
      each_cluster(string) { |_chars, cluster_width| total += cluster_width }
      total
    end

    private def emoji_base?(char : Char) : Bool
      in_ranges?(char.ord, EMOJI_BASES)
    end

    private def in_ranges?(codepoint : Int32, ranges : Array(Tuple(Int32, Int32))) : Bool
      ranges.each do |range|
        return true if codepoint >= range[0] && codepoint <= range[1]
      end
      false
    end
  end
end
