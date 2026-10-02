require "./spec_helper"

describe "path input" do
  it "uses the current directory when no path is given" do
    implicit = SpecSupport.run!(["-c", "-d", "0"])
    explicit = SpecSupport.run!(["-c", "-d", "0", "."])
    dotted = SpecSupport.run!(["-c", "-d", "0", "./"])

    implicit.should eq(explicit)
    explicit.should eq(dotted)
    implicit.should contain("┌── .")
  end

  it "reads paths with --files-from" do
    output = SpecSupport.run!(["--files-from", SpecSupport.fixture("test_dir_files_from/files_from.txt")])
    output.should contain("a_file")
    output.should contain("hello_file")
  end

  it "reads paths with --files0-from" do
    output = SpecSupport.run!(["--files0-from", SpecSupport.fixture("test_dir_files_from/files0_from.txt")])
    output.should contain("a_file")
    output.should contain("hello_file")
  end

  it "reads newline separated paths from stdin" do
    input = "spec/fixtures/test_dir_files_from/a_file\nspec/fixtures/test_dir_files_from/hello_file\n"
    result = SpecSupport.run(["--files-from", "-"], input)
    result.error.should be_empty
    result.output.should contain("a_file")
    result.output.should contain("hello_file")
  end

  it "ignores empty lines in --files-from" do
    input = "spec/fixtures/test_dir_files_from/a_file\n\nspec/fixtures/test_dir_files_from/hello_file\n"
    result = SpecSupport.run(["--files-from", "-"], input)
    result.error.should be_empty
    result.output.should contain("a_file")
    result.output.should contain("hello_file")
  end

  it "reads NUL terminated paths from stdin" do
    input = "spec/fixtures/test_dir_files_from/a_file\0spec/fixtures/test_dir_files_from/hello_file\0"
    result = SpecSupport.run(["--files0-from", "-"], input)
    result.error.should be_empty
    result.output.should contain("a_file")
    result.output.should contain("hello_file")
  end

  it "ignores empty path arguments" do
    output = SpecSupport.run!(["-b", "-c", "-d", "0",
                               SpecSupport.fixture("test_dir_files_from/a_file"), "",
                               SpecSupport.fixture("test_dir_files_from/hello_file")])
    output.should contain("a_file")
    output.should contain("hello_file")
  end

  it "reports a missing path" do
    result = SpecSupport.run(["bad_place_xyz"])
    result.success?.should be_false
    result.error.should contain("No such file or directory")
  end
end
