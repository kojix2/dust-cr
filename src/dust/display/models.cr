require "../color"
require "../display_node"

module Dust
  class RenderOptions
    getter? short_paths : Bool
    getter? is_reversed : Bool
    getter? colors_on : Bool
    getter? dim : Bool
    getter? by_filecount : Bool
    getter? screen_reader : Bool
    getter output_format : String
    getter? right_bars : Bool

    def initialize(@short_paths : Bool, @is_reversed : Bool, @colors_on : Bool, @dim : Bool,
                   @by_filecount : Bool, @screen_reader : Bool, @output_format : String,
                   @right_bars : Bool)
    end
  end

  class RenderContext
    BLOCKS = ['█', '▓', '▒', '░', ' ']

    getter options : RenderOptions
    getter size_width : Int32
    getter base_size : UInt64
    getter name_width : Int32
    getter ls_colors : Color::LsColors

    def initialize(@options : RenderOptions, @size_width : Int32,
                   @base_size : UInt64, @name_width : Int32,
                   @ls_colors : Color::LsColors = Color::LsColors.from_env)
    end

    def tree_chars(last : Bool, has_children : Bool) : String
      if @options.is_reversed?
        return has_children ? "┌─┴" : "┌──" if last

        has_children ? "├─┴" : "├──"
      else
        return has_children ? "└─┬" : "└──" if last

        has_children ? "├─┬" : "├──"
      end
    end

    # The largest entry of its level gets printed in red.
    def biggest?(index : Int32, count : Int32) : Bool
      @options.is_reversed? ? index == count - 1 : index == 0
    end

    # The last entry printed at its level drives `└` versus `├`.
    def last?(index : Int32, count : Int32) : Bool
      @options.is_reversed? ? index == 0 : index == count - 1
    end

    def percent_size(node : DisplayNode) : Float64
      result = node.size.to_f64 / @base_size.to_f64
      !result.nan? && !result.infinite? && result > 0 ? result : 0.0
    end
  end

  class DrawState
    getter indent : String
    getter percent_bar : String
    getter context : RenderContext

    def initialize(@indent : String, @percent_bar : String, @context : RenderContext)
    end

    def next_indent(has_children : Bool, last : Bool) : String
      @indent + @context.tree_chars(last, has_children)
    end

    # Shades the parent's bar: the part this node fills becomes `█`, while the
    # part inherited from its ancestors becomes progressively lighter.
    def generate_bar(node : DisplayNode, level : Int32) : String
      return level.to_s if @context.options.screen_reader?

      chars = @percent_bar.chars
      inherited = chars.size - (chars.size * @context.percent_size(node)).to_i32
      shade = RenderContext::BLOCKS[5 - level.clamp(1, 4)]

      bar = String.build do |io|
        iterator = @context.options.right_bars? ? chars : chars.reverse
        iterator.each do |char|
          inherited -= 1
          if inherited <= 0
            io << RenderContext::BLOCKS[0]
          elsif char == RenderContext::BLOCKS[0]
            io << shade
          else
            io << char
          end
        end
      end

      @context.options.right_bars? ? bar : bar.chars.reverse!.join
    end
  end
end
