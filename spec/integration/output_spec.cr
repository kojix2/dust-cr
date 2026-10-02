require "json"

require "./spec_helper"

describe "output modes" do
  it "prints no colors with -c" do
    output = SpecSupport.run!(["-c", "spec/fixtures/test_dir/"])
    output.should_not contain("\e[31m")
    output.should_not contain("\e[0m")
  end

  it "forces colors with -C" do
    output = SpecSupport.run!(["-C", "spec/fixtures/test_dir/"])
    output.should contain("\e[31m")
    output.should contain("\e[0m")
  end

  it "prints JSON with -j" do
    output = SpecSupport.run!(["-j", SpecSupport.fixture("test_dir/")])
    json = JSON.parse(output)
    json["name"].as_s.should eq(SpecSupport.fixture("test_dir/").chomp('/'))
    json["size"].as_s.should eq("4.0Ki")
    json["children"].as_a.size.should eq(1)
  end

  it "prints sizes in powers of 1000 with -o si" do
    output = SpecSupport.run!(["-c", "-o", "si", SpecSupport.fixture("test_dir2")])
    output.should contain("12K ┌─┴")
  end

  it "prints sizes in a fixed unit with -o" do
    output = SpecSupport.run!(["-c", "-o", "kib", SpecSupport.fixture("test_dir2")])
    output.should contain("12Ki ┌─┴")

    output = SpecSupport.run!(["-c", "-o", "b", SpecSupport.fixture("test_dir2")])
    output.should contain("12288B ┌─┴ test_dir2")
  end

  it "moves the bars to the right with -B" do
    output = SpecSupport.run!(["-c", "-B", SpecSupport.fixture("test_dir/")])
    output.should contain("░█ │   0%")
    output.lines.first.should end_with("█ │   0%")
  end

  it "prints --version" do
    SpecSupport.run!(["--version"]).should contain("Dust 1.2.6")
  end

  it "reports a bad regex and exits" do
    result = SpecSupport.run(["-e", "[unclosed", "spec/fixtures/test_dir"])
    result.exit_code.should eq(1)
    result.error.should contain("Ignoring bad value for regex")
  end

  it "fails on an unknown flag" do
    result = SpecSupport.run(["--not-a-flag"])
    result.exit_code.should eq(2)
    result.error.should contain("unexpected argument '--not-a-flag' found")
  end

  it "fails on conflicting flags" do
    result = SpecSupport.run(["-D", "-F", "spec/fixtures/test_dir"])
    result.exit_code.should eq(2)
    result.error.should contain("cannot be used with")
  end
end
