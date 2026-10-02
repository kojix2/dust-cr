require "./cli/options"
require "./display"
require "./display_node"
require "./term"

module Dust
  # Serializes or draws the filtered result tree for one invocation.
  class Presenter
    def initialize(@options : CLI::Options, @output : IO = STDOUT)
    end

    def render(tree : DisplayNode) : Nil
      if @options.output_json?
        output_type = @options.filecount? ? "count" : @options.format_name
        tree.to_json(@output, output_type)
        @output << '\n'
        return
      end

      render_options = RenderOptions.new(
        short_paths: !@options.full_paths?,
        is_reversed: !@options.reverse?,
        colors_on: colors_enabled?,
        dim: @options.dim?,
        by_filecount: @options.filecount?,
        screen_reader: @options.screen_reader?,
        output_format: @options.format_name,
        right_bars: @options.right_bars?
      )

      Renderer.new(@output).draw(render_options, tree, @options.hide_bars?,
        @options.terminal_width || Term.width, @options.skip_total?)
    end

    private def colors_enabled? : Bool
      return true if @options.force_colors?
      return false if @options.no_colors? || ENV["NO_COLOR"]?

      @output.tty?
    end
  end
end
