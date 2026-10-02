require "../platform"
require "../size_format"
require "../unicode_width"
require "./models"
require "./text"

module Dust
  class Renderer
    def initialize(@output : IO = STDOUT)
    end

    def draw(options : RenderOptions, root : DisplayNode, hide_bars : Bool,
             width : Int32, skip_total : Bool) : Nil
      size_width = if options.by_filecount?
                     Display::Text.commas(root.size).size.to_i32
                   else
                     size_width(root, options.output_format)
                   end

      raise "Not enough terminal width" unless width > size_width + 2

      allowed_width = width - size_width - 2
      name_width = tree_width(root, 3, allowed_width, options)
      bar_width = if hide_bars || name_width + 7 >= allowed_width
                    0
                  else
                    allowed_width - name_width - 7
                  end

      context = RenderContext.new(options, size_width, root.size, name_width)
      state = DrawState.new("", RenderContext::BLOCKS[0].to_s * bar_width, context)

      if skip_total
        root.ordered_children(options.is_reversed?).each_with_index do |child, index|
          sibling_count = root.num_siblings.to_i32
          draw_node(child, state,
            context.biggest?(index, sibling_count),
            context.last?(index, sibling_count))
        end
      else
        draw_node(root, state, true, true)
      end
    end

    def format_line(node : DisplayNode, indent : String, bars : String, biggest : Bool,
                    context : RenderContext) : String
      percent, padded = label(node, indent, bars, context)
      size = pretty_size(node, biggest, context)
      name = pretty_name(node, padded, context)

      if context.options.screen_reader?
        "#{name} #{bars} #{size}#{percent}"
      else
        "#{size} #{indent} #{name}#{percent}"
      end
    end

    private def size_width(node : DisplayNode, output_format : String) : Int32
      width = SizeFormat.humanize(node.size, output_format).size.to_i32
      node.children.each do |child|
        width = Math.max(width, size_width(child, output_format))
      end
      width
    end

    private def tree_width(node : DisplayNode, indent : Int32, terminal : Int32,
                           options : RenderOptions) : Int32
      name = Display::Text.printable_name(node.name, options.short_paths?)
      width = UnicodeWidth.width(name)
      longest = options.screen_reader? ? width + 1 : Math.min(width + 1 + indent, terminal)

      node.children.each do |child|
        longest = Math.max(longest, tree_width(child, indent + 2, terminal, options))
      end
      longest
    end

    private def draw_node(node : DisplayNode, state : DrawState, biggest : Bool,
                          last : Bool) : Nil
      indent = state.next_indent(!node.children.empty?, last)
      level = ((indent.size - 1) // 2) - 1
      bar = state.generate_bar(node, level)
      line = format_line(node, indent, bar, biggest, state.context)

      @output.puts line unless state.context.options.is_reversed?

      child_state = DrawState.new(clean_indent(indent), bar, state.context)
      sibling_count = node.num_siblings.to_i32
      node.ordered_children(state.context.options.is_reversed?).each_with_index do |child, index|
        draw_node(child, child_state,
          child_state.context.biggest?(index, sibling_count),
          child_state.context.last?(index, sibling_count))
      end

      @output.puts line if state.context.options.is_reversed?
    end

    private def clean_indent(indent : String) : String
      cleaned = indent
      # Reversed tree.
      cleaned = cleaned.gsub("┌─┴", "  ")
      cleaned = cleaned.gsub("┌──", "  ")
      cleaned = cleaned.gsub("├─┴", "│ ")
      cleaned = cleaned.gsub("─┴", " ")
      # Normal tree.
      cleaned = cleaned.gsub("└─┬", "  ")
      cleaned = cleaned.gsub("└──", "  ")
      cleaned = cleaned.gsub("├─┬", "│ ")
      cleaned = cleaned.gsub("─┬", " ")
      # Both directions.
      cleaned.gsub("├──", "│ ")
    end

    private def pad_name(node : DisplayNode, indent : String, context : RenderContext) : String
      name = Display::Text.printable_name(node.name, context.options.short_paths?)
      width = UnicodeWidth.width("#{indent} #{name}")
      unless context.name_width >= width
        raise "Terminal width not wide enough to draw directory tree"
      end

      name + " " * (context.name_width - width)
    end

    private def trim_name(name : String, indent : String, context : RenderContext) : String
      indent_width = UnicodeWidth.width(indent)
      unless context.name_width >= indent_width + 2
        raise "Terminal width not wide enough to draw directory tree"
      end

      max_width = context.name_width - indent_width
      return name unless UnicodeWidth.width(name) > max_width

      width_left = max_width - 2
      String.build do |io|
        UnicodeWidth.each_cluster(name) do |chars, cluster_width|
          break if cluster_width > width_left

          width_left -= cluster_width
          chars.each { |char| io << char }
        end
      end + ".."
    end

    private def label(node : DisplayNode, indent : String, bar : String,
                      context : RenderContext) : {String, String}
      if context.options.screen_reader?
        percent = context.percent_size(node) * 100.0
        {" " + (sprintf("%.0f", percent) + "%").rjust(4), pad_name(node, "", context)}
      elsif !bar.empty?
        colored_bar = if context.options.dim?
                        Color.paint(bar, Color::DARK_GRAY)
                      else
                        bar
                      end
        percent = (sprintf("%.0f", context.percent_size(node) * 100.0) + "%").rjust(4)
        {"│#{colored_bar} │ #{percent}", pad_name(node, indent, context)}
      else
        name = Display::Text.printable_name(node.name, context.options.short_paths?)
        {"", trim_name(name, indent, context)}
      end
    end

    private def pretty_size(node : DisplayNode, biggest : Bool, context : RenderContext) : String
      size = if context.options.by_filecount?
               Display::Text.commas(node.size)
             else
               SizeFormat.humanize(node.size, context.options.output_format)
             end

      size = " " * (context.size_width - size.size) + size
      biggest && context.options.colors_on? ? Color.paint(size, Color::RED) : size
    end

    private def pretty_name(node : DisplayNode, name : String, context : RenderContext) : String
      return name unless context.options.colors_on?

      kind = Platform.lstat(node.name).try { |stat| Platform.kind_of(stat) } || FileKind::Other
      if code = context.ls_colors.style_for(node.name, kind)
        Color.paint(name, code)
      else
        name
      end
    end
  end
end
