module SpecSupport::Render
  extend self

  def options(**values) : Dust::RenderOptions
    Dust::RenderOptions.new(
      short_paths: values[:short_paths]? || true,
      is_reversed: values[:is_reversed]? || false,
      colors_on: false,
      dim: values[:dim]? || false,
      by_filecount: false,
      screen_reader: values[:screen_reader]? || false,
      output_format: "",
      right_bars: values[:right_bars]? || false
    )
  end

  def context(width : Int32, **values) : Dust::RenderContext
    Dust::RenderContext.new(options(**values), 5, 4096_u64, width, Dust::Color::LsColors.new)
  end

  def state(context : Dust::RenderContext, size : UInt64,
            bars : String = "█" * 13) : Dust::DrawState
    Dust::DrawState.new("", bars, context)
  end

  def node(size : UInt64) : Dust::DisplayNode
    Dust::DisplayNode.new(size, "/short", [] of Dust::DisplayNode)
  end
end
