require "../spec_helper"

require "../../src/dust/input_paths"

describe Dust::Inputs do
  it "defaults to the current directory" do
    options = Dust::CLI::Options.new
    Dust::Inputs.new(options).resolve.should eq(["."])
  end

  it "keeps positional paths and discards empty ones" do
    options = Dust::CLI::Options.new
    options.params = ["one", "", "two"]
    Dust::Inputs.new(options).resolve.should eq(["one", "two"])
  end

  it "reads newline-separated paths from the injected input" do
    options = Dust::CLI::Options.new
    options.files_from = "-"
    input = IO::Memory.new("one\n\ntwo\n")

    Dust::Inputs.new(options, input).resolve.should eq(["one", "two"])
  end

  it "reads NUL-separated paths from the injected input" do
    options = Dust::CLI::Options.new
    options.files0_from = "-"
    input = IO::Memory.new("one\0two\0")

    Dust::Inputs.new(options, input).resolve.should eq(["one", "two"])
  end
end
