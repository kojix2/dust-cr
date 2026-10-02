require "json"

require "./spec_helper"
require "../support/files"

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
    path = SpecSupport.fixture("test_dir/many/hello_file")
    output = SpecSupport.run!(["-j", "-s", path])
    json = JSON.parse(output)
    json["name"].as_s.should eq(path)
    json["size"].as_s.should eq("6B")
    json["children"].as_a.should be_empty
  end

  it "formats sizes with -o" do
    SpecSupport.temp_dir("dust-cr-output") do |dir|
      path = File.join(dir, "sample")
      File.write(path, "x" * 12_288)

      SpecSupport.run!(["-c", "-s", "-o", "si", path]).should contain("12K ┌── sample")
      SpecSupport.run!(["-c", "-s", "-o", "kib", path]).should contain("12Ki ┌── sample")
      SpecSupport.run!(["-c", "-s", "-o", "b", path]).should contain("12288B ┌── sample")
    end
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
