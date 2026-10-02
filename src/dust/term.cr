{% if flag?(:x86_64) || flag?(:aarch64) %}
  alias ULongT = UInt64
{% else %}
  alias ULongT = UInt32
{% end %}

module Dust
  # Terminal dimensions, mirroring the `terminal_size` crate dust uses:
  # ioctl(TIOCGWINSZ) on stdout, then COLUMNS/LINES, then the defaults.
  module Term
    extend self

    DEFAULT_WIDTH  = 80
    DEFAULT_HEIGHT = 30

    def size : {Int32, Int32}?
      if dimensions = ioctl_size
        return dimensions
      end

      width = ENV["COLUMNS"]?.try(&.to_i?)
      height = ENV["LINES"]?.try(&.to_i?)
      return unless width && height && width > 0 && height > 0

      {width, height}
    end

    def width : Int32
      size.try(&.[0]) || DEFAULT_WIDTH
    end

    # dust subtracts a fixed amount of lines so that the output plus shell
    # prompts fit on screen.
    def height : Int32
      detected = size.try(&.[1]) || DEFAULT_HEIGHT
      Math.max(detected, DEFAULT_HEIGHT) - 10
    end

    private def ioctl_size : {Int32, Int32}?
      return unless STDOUT.tty?

      winsize = uninitialized LibC::Winsize
      return unless LibC.ioctl(STDOUT.fd, TIOCGWINSZ, pointerof(winsize)) == 0
      return if winsize.ws_col == 0 || winsize.ws_row == 0

      {winsize.ws_col.to_i32, winsize.ws_row.to_i32}
    end

    {% if flag?(:linux) || flag?(:android) %}
      TIOCGWINSZ = 0x5413_u64
    {% else %}
      TIOCGWINSZ = 0x40087468_u64
    {% end %}
  end
end

{% unless flag?(:windows) %}
  lib LibC
    struct Winsize
      ws_row : LibC::UShort
      ws_col : LibC::UShort
      ws_xpixel : LibC::UShort
      ws_ypixel : LibC::UShort
    end

    fun ioctl(fd : Int32, request : ULongT, ...) : Int32
  end
{% end %}
