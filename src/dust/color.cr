module Dust
  # ANSI escapes and LS_COLORS lookup for file names.
  module Color
    extend self

    RESET = "\e[0m"

    RED       = "31"
    DARK_GRAY = "90"

    def paint(text : String, code : String) : String
      "\e[#{code}m#{text}#{RESET}"
    end

    # Minimal LS_COLORS support: directory, symlink, file and extension rules.
    class LsColors
      @codes = Hash(String, String).new
      @by_extension = Hash(String, String).new

      # The defaults the `lscolors` crate falls back on when LS_COLORS is unset.
      DEFAULT_CODES = {
        "di"     => "01;34",
        "ln"     => "01;36",
        "so"     => "01;35",
        "pi"     => "33",
        "ex"     => "01;32",
        "bd"     => "40;33;01",
        "cd"     => "40;33;01",
        "su"     => "37;41",
        "sg"     => "30;43",
        "tw"     => "30;42",
        "ow"     => "34;42",
        "st"     => "37;44",
        "*.jpg"  => "01;35",
        "*.jpeg" => "01;35",
        "*.png"  => "01;35",
        "*.gif"  => "01;35",
        "*.webp" => "01;35",
        "*.mp3"  => "00;36",
        "*.mp4"  => "00;36",
        "*.tar"  => "01;31",
        "*.gz"   => "01;31",
        "*.zip"  => "01;31",
        "*.rar"  => "01;31",
        "*.7z"   => "01;31",
      }

      def initialize
        DEFAULT_CODES.each { |key, code| store(key, code) }
      end

      def self.from_env : LsColors
        colors = new
        if ls_colors = ENV["LS_COLORS"]?
          colors.load(ls_colors)
        end
        colors
      end

      protected def load(ls_colors : String) : Nil
        ls_colors.split(':').each do |entry|
          key, code = entry.split('=', 2)
          next if code.nil? || code.empty?

          store(key, code)
        end
      end

      protected def store(key : String, code : String) : Nil
        # LS_COLORS codes are semicolon separated numbers; nu_ansi_term drops
        # leading zeros, so `01;34` becomes `1;34`.
        normalized = code.split(';').map { |part| part.to_i? ? part.to_i.to_s : part }.join(';')
        @codes[key] = normalized
        @by_extension[key[2..]] = normalized if key.starts_with?("*.")
      end

      def style_for(name : String, kind : FileKind) : String?
        case kind
        when FileKind::Directory
          @codes["di"]?
        when FileKind::Symlink
          @codes["ln"]? || @codes["or"]?
        else
          extension = File.extname(name).lstrip('.')
          if !extension.empty?
            code = @by_extension[extension]?
            return code if code
            # LS_COLORS patterns may contain more than one dot, eg `*tar.gz`.
            @by_extension.each do |pattern, pattern_code|
              return pattern_code if pattern.ends_with?(extension) && pattern.includes?('.')
            end
          end
          @codes["fi"]?
        end
      end
    end
  end
end
