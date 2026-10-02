require "../spec_helper"

require "../../src/dust/cli"

# Exercise the argument forms that dust relies on from Crystal's OptionParser.
describe Dust::CLI::Parser do
  it "reads long flags with a separate value" do
    options = Dust::CLI::Parser.new.parse(["--depth", "3"])
    options.depth.should eq(3)
  end

  it "reads long flags with an inline value" do
    Dust::CLI::Parser.new.parse(["--depth=3"]).depth.should eq(3)
  end

  it "reads short flags with an attached value" do
    Dust::CLI::Parser.new.parse(["-n5"]).lines.should eq(5)
  end

  it "reads short flags with a separate value" do
    Dust::CLI::Parser.new.parse(["-n", "5"]).lines.should eq(5)
  end

  it "clusters boolean short flags" do
    options = Dust::CLI::Parser.new.parse(["-cb"])
    options.no_colors?.should be_true
    options.hide_bars?.should be_true
  end

  it "collects repeated value flags as regexes" do
    Dust::CLI::Parser.new.parse(["-e", "a", "-e", "b"]).filter.map(&.source).should eq(["a", "b"])
    Dust::CLI::Parser.new.parse(["-v", "c", "-v", "d"]).invert_filter.map(&.source).should eq(["c", "d"])
  end

  it "collects positional paths" do
    options = Dust::CLI::Parser.new.parse(["a", "-c", "b"])
    options.no_colors?.should be_true
    options.params.should eq(["a", "b"])
  end

  it "stops parsing flags after --" do
    options = Dust::CLI::Parser.new.parse(["--", "-c"])
    options.params.should eq(["-c"])
    options.no_colors?.should be_false
  end

  it "keeps a dash prefixed value" do
    Dust::CLI::Parser.new.parse(["-e", "-x$"]).filter.first.source.should eq("-x$")
  end

  it "has an unlimited depth by default" do
    Dust::CLI::Parser.new.parse([] of String).depth.should eq(Dust::CLI::UNLIMITED_DEPTH)
  end

  it "lowercases the output format" do
    Dust::CLI::Parser.new.parse(["-o", "KIB"]).output_format.should eq("kib")
  end
end
