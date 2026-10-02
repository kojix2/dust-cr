require "c/sys/stat"
require "file_utils"

require "./spec_helper"

# Ported from dust's tests/test_exact_output.rs.
#
# The fixtures are copied to a short temporary path so the expected strings do
# not depend on the checkout path. Several variants account for filesystem
# block sizes on macOS, Linux, and 64k block devices.
module ExactOutput
  extend self

  TMP = File.tempname("dust-cr-exact")

  def setup : Nil
    FileUtils.mkdir_p(TMP)

    %w[test_dir test_dir2 test_dir_unicode].each do |dir|
      FileUtils.cp_r(SpecSupport.fixture(dir), TMP)
    end

    unreadable = File.join(TMP, "unreadable_dir")
    FileUtils.mkdir_p(unreadable)
    LibC.chmod(unreadable, 0o000_u32)
  end

  def cleanup : Nil
    LibC.chmod(path("unreadable_dir"), 0o755_u32)
    FileUtils.rm_rf(TMP)
  end

  def path(name : String, trailing_slash : Bool = false) : String
    joined = File.join(TMP, name)
    trailing_slash ? "#{joined}/" : joined
  end

  def width : Int32
    80 + TMP.size - "/tmp".size
  end

  def matches_any?(output : String, expected : Array(String)) : Bool
    expected.any? { |variant| output.includes?(variant) }
  end

  def tree : Array(String)
    [
      "0B     ┌── a_file    │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█ │   0%\n4.0Ki     ├── hello_file│████████████████████████████████████████████████ │ 100%\n4.0Ki   ┌─┴ many        │████████████████████████████████████████████████ │ 100%\n4.0Ki ┌─┴ test_dir      │████████████████████████████████████████████████ │ 100%",
      "0B     ┌── a_file    │               ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█ │   0%\n4.0Ki     ├── hello_file│               ░░░░░░░░░░░░░░░░█████████████████ │  33%\n8.0Ki   ┌─┴ many        │               █████████████████████████████████ │  67%\n 12Ki ┌─┴ test_dir      │████████████████████████████████████████████████ │ 100%",
      "0B     ┌── a_file    │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█ │   0%\n64K     ├── hello_file│██████████████████████████████████████████████████ │ 100%\n64K   ┌─┴ many        │██████████████████████████████████████████████████ │ 100%\n64K ┌─┴ test_dir      │██████████████████████████████████████████████████ │ 100%",
    ]
  end

  def long_tree : Array(String)
    variants = [
      "0B     ┌── /tmp/test_dir/many/a_file    │░░░░░░░░░░░░░░░░░░░░░░░░░░░░█ │   0%\n4.0Ki     ├── /tmp/test_dir/many/hello_file│█████████████████████████████ │ 100%\n4.0Ki   ┌─┴ /tmp/test_dir/many             │█████████████████████████████ │ 100%\n4.0Ki ┌─┴ /tmp/test_dir                    │█████████████████████████████ │ 100%",
      "0B     ┌── /tmp/test_dir/many/a_file    │         ░░░░░░░░░░░░░░░░░░░█ │   0%\n4.0Ki     ├── /tmp/test_dir/many/hello_file│         ░░░░░░░░░░██████████ │  33%\n8.0Ki   ┌─┴ /tmp/test_dir/many             │         ████████████████████ │  67%\n 12Ki ┌─┴ /tmp/test_dir                    │█████████████████████████████ │ 100%",
      "0B     ┌── /tmp/test_dir/many/a_file    │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█ │   0%\n64K     ├── /tmp/test_dir/many/hello_file│███████████████████████████████ │ 100%\n64K   ┌─┴ /tmp/test_dir/many             │███████████████████████████████ │ 100%\n64K ┌─┴ /tmp/test_dir                    │███████████████████████████████ │ 100%",
    ]
    variants.map(&.gsub("/tmp", TMP))
  end

  def names : Array(String)
    [
      "0B   ┌── long_dir_name_what_a_very_long_dir_name_what_happens_when_this_goe..\n4.0Ki   ├── dir_name_clash\n4.0Ki   │ ┌── hello\n8.0Ki   ├─┴ dir\n4.0Ki   │ ┌── hello\n8.0Ki   ├─┴ dir_substring\n 24Ki ┌─┴ test_dir2",
      "0B   ┌── long_dir_name_what_a_very_long_dir_name_what_happens_when_this_goe..\n4.0Ki   │ ┌── hello\n4.0Ki   ├─┴ dir\n4.0Ki   ├── dir_name_clash\n4.0Ki   │ ┌── hello\n4.0Ki   ├─┴ dir_substring\n 12Ki ┌─┴ test_dir2",
      "0B   ┌── long_dir_name_what_a_very_long_dir_name_what_happens_when_this_goes..\n 64K   │ ┌── hello\n 64K   ├─┴ dir\n 64K   ├── dir_name_clash\n 64K   │ ┌── hello\n 64K   ├─┴ dir_substring\n192K ┌─┴ test_dir2",
      "0B   ┌── long_dir_name_what_a_very_long_dir_name_what_happens_when_this_goes..\n 64K   ├── dir_name_clash\n 64K   │ ┌── hello\n 64K   ├─┴ dir\n 64K   │ ┌── hello\n 64K   ├─┴ dir_substring\n192K ┌─┴ test_dir2",
    ]
  end

  def unicode : Array(String)
    [
      "0B   ┌── 日本語のファイル名です.txt│                                 █ │   0%\n   0B   ├── 👩.unicode                │                                 █ │   0%\n4.0Ki ┌─┴ test_dir_unicode            │██████████████████████████████████ │ 100%",
      "0B   ┌── 日本語のファイル名です.txt│                                    █ │   0%\n0B   ├── 👩.unicode                │                                    █ │   0%\n0B ┌─┴ test_dir_unicode            │                                    █ │   0%",
      "0B   ┌── 日本語のファイル名です.txt│                                  █ │   0%\n  0B   ├── 👩.unicode                │                                  █ │   0%\n 64K ┌─┴ test_dir_unicode            │███████████████████████████████████ │ 100%",
    ]
  end

  def apparent : Array(String)
    [
      "0B     ┌── a_file\n  6B     ├── hello_file",
      "0B     ┌── a_file\n   6B     ├── hello_file",
    ]
  end
end

Spec.before_suite { ExactOutput.setup }
Spec.after_suite { ExactOutput.cleanup }

describe "dust exact output" do
  it "prints the basic tree" do
    output = SpecSupport.run!(["-c", "-B", ExactOutput.path("test_dir", true)])
    ExactOutput.matches_any?(output, ExactOutput.tree).should be_true
  end

  it "prints the same tree for several arguments" do
    output = SpecSupport.run!(["-c", "-B", ExactOutput.path("test_dir/many", true),
                               ExactOutput.path("test_dir"), ExactOutput.path("test_dir")])
    ExactOutput.matches_any?(output, ExactOutput.tree).should be_true
  end

  it "prints full paths with -p" do
    output = SpecSupport.run!(["-c", "-p", "-B", "-w", ExactOutput.width.to_s,
                               ExactOutput.path("test_dir", true)])
    ExactOutput.matches_any?(output, ExactOutput.long_tree).should be_true
  end

  it "truncates long names without matching substrings" do
    output = SpecSupport.run!(["-c", "-B", ExactOutput.path("test_dir2")])
    ExactOutput.matches_any?(output, ExactOutput.names).should be_true
  end

  it "aligns unicode names by display width" do
    output = SpecSupport.run!(["-c", "-B", ExactOutput.path("test_dir_unicode")])
    ExactOutput.matches_any?(output, ExactOutput.unicode).should be_true
  end

  it "reports file length with -s" do
    output = SpecSupport.run!(["-c", "-s", "-b", ExactOutput.path("test_dir")])
    ExactOutput.matches_any?(output, ExactOutput.apparent).should be_true
  end

  it "prints one permission message" do
    result = SpecSupport.run([ExactOutput.path("unreadable_dir")])
    result.error.strip.should eq(
      "Did not have permissions for all directories (add --print-errors to see errors)"
    )
  end

  it "prints the unreadable directories with --print-errors" do
    result = SpecSupport.run(["--print-errors", ExactOutput.path("unreadable_dir")])
    result.error.strip.should eq(
      "Did not have permissions for directories: #{ExactOutput.path("unreadable_dir")}"
    )
  end
end
