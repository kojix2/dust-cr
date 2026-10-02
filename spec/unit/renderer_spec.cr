require "../spec_helper"

require "../../src/dust/display"
require "../support/render"

describe Dust::Renderer do
  describe "#format_line" do
    it "renders a short line" do
      node = Dust::DisplayNode.new(4096_u64, "/short", [] of Dust::DisplayNode)
      Dust::Renderer.new.format_line(node, "┌─┴", "", false, SpecSupport::Render.context(20)).should eq("4.0Ki ┌─┴ short")
    end

    it "truncates long names" do
      name = "very_long_name_longer_than_the_eighty_character_limit_very_long_name_this_bit_will_truncate"
      node = Dust::DisplayNode.new(4096_u64, name, [] of Dust::DisplayNode)
      Dust::Renderer.new.format_line(node, "┌─┴", "", false, SpecSupport::Render.context(64)).should eq(
        "4.0Ki ┌─┴ very_long_name_longer_than_the_eighty_character_limit_very_.."
      )
    end

    it "truncates wide characters by display width" do
      name = "日本語のファイル名です日本語のファイル名です"
      node = Dust::DisplayNode.new(4096_u64, name, [] of Dust::DisplayNode)
      line = Dust::Renderer.new.format_line(node, "┌─┴", "", false, SpecSupport::Render.context(20))
      line.should eq("4.0Ki ┌─┴ 日本語のファイ..")
      # 7 wide characters, 3 tree characters, the size and two spaces.
      Dust::UnicodeWidth.width(line).should eq(26)
    end

    it "renders the screen reader line" do
      node = Dust::DisplayNode.new(4096_u64, "/short", [] of Dust::DisplayNode)
      line = Dust::Renderer.new.format_line(node, "", "3", false, SpecSupport::Render.context(20, screen_reader: true))
      line.should eq("short               3 4.0Ki 100%")
    end
  end

  describe "DrawState#generate_bar" do
    it "fills the whole bar at the first level" do
      context = SpecSupport::Render.context(20)
      SpecSupport::Render.state(context, 4096_u64).generate_bar(SpecSupport::Render.node(4096_u64), 1).should eq("█" * 13)
    end

    it "shades the inherited part lighter at deeper levels" do
      context = SpecSupport::Render.context(20)
      state = SpecSupport::Render.state(context, 2048_u64)
      state.generate_bar(SpecSupport::Render.node(2048_u64), 2).should eq("███████░░░░░░")
      state.generate_bar(SpecSupport::Render.node(2048_u64), 3).should eq("███████▒▒▒▒▒▒")
    end

    it "fills from the right" do
      context = SpecSupport::Render.context(20, right_bars: true)
      state = SpecSupport::Render.state(context, 2048_u64)
      state.generate_bar(SpecSupport::Render.node(2048_u64), 3).should eq("▒▒▒▒▒▒███████")
    end

    it "stops shading after the fourth level" do
      context = SpecSupport::Render.context(20)
      state = SpecSupport::Render.state(context, 1024_u64)
      state.generate_bar(SpecSupport::Render.node(1024_u64), 4).should eq("████▓▓▓▓▓▓▓▓▓")
      state.generate_bar(SpecSupport::Render.node(1024_u64), 5).should eq("████▓▓▓▓▓▓▓▓▓")
    end
  end

  describe "#commas" do
    it "groups digits" do
      Dust::Display::Text.commas(1_u64).should eq("1")
      Dust::Display::Text.commas(999_u64).should eq("999")
      Dust::Display::Text.commas(1_000_u64).should eq("1,000")
      Dust::Display::Text.commas(1_234_567_u64).should eq("1,234,567")
    end
  end

  describe "#get_printable_name" do
    it "shortens to the basename" do
      Dust::Display::Text.printable_name("/a/b/c", true).should eq("c")
      Dust::Display::Text.printable_name("a/b/", true).should eq("a/b/")
    end

    it "keeps the whole path when asked" do
      Dust::Display::Text.printable_name("/a/b/c", false).should eq("/a/b/c")
    end
  end

  describe "JSON output" do
    it "applies each requested format without shared state" do
      display_node = Dust::DisplayNode.new(1024_u64, "file", [] of Dust::DisplayNode)

      JSON.parse(display_node.to_json("b"))["size"].as_s.should eq("1024B")
      JSON.parse(display_node.to_json("kib"))["size"].as_s.should eq("1Ki")
      JSON.parse(display_node.to_json("count"))["size"].as_s.should eq("1024")
    end
  end
end
