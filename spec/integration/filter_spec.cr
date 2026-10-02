require "./spec_helper"

describe "filters" do
  it "ignores directories with -X" do
    output = SpecSupport.run!(["-c", "-X", "dir_substring", SpecSupport.fixture("test_dir2/")])
    output.should_not contain("dir_substring")
  end

  it "filters files by regex" do
    output = SpecSupport.run!(["-c", "-e", "\\.cr$", "src"])
    output.should contain(" ┌─┴ src")
    output.should_not contain("0B ┌── src")
    output.should_not contain("0B ┌─┴ src")
  end

  it "shows nothing but the root when the regex matches nothing" do
    output = SpecSupport.run!(["-c", "-e", "match_nothing$", "spec/fixtures"])
    output.should contain("0B ┌── fixtures")
  end

  it "accepts several -e filters" do
    output = SpecSupport.run!(["-c", "-e", "test_dir_hidden", "-e", "test_dir2", "-n", "100",
                               "spec/fixtures"])
    output.should contain("test_dir2")
    output.should contain("test_dir_hidden")
    output.should_not contain("many")
  end

  it "excludes files by regex with -v" do
    output = SpecSupport.run!(["-c", "-f", "-v", "e", "spec/fixtures/test_dir2"])
    output.should contain("0 ┌── test_dir2")

    output = SpecSupport.run!(["-c", "-f", "-v", "a", "spec/fixtures/test_dir2"])
    output.should contain("2 ┌─┴ test_dir2")

    output = SpecSupport.run!(["-c", "-f", "-v", "match_nothing$", "spec/fixtures/test_dir2"])
    output.should contain("4 ┌─┴ test_dir2")
  end

  it "accepts several -v filters" do
    output = SpecSupport.run!(["-c", "-v", "test_dir2", "-v", "test_dir_unicode", "-n", "100",
                               "spec/fixtures"])
    output.should_not contain("test_dir2")
    output.should_not contain("test_dir_unicode")
    output.should contain("many")
  end

  it "honours --min-size" do
    output = SpecSupport.run!(["-c", "-z", "4Ki", "spec/fixtures/test_dir2"])
    output.should_not contain("dir_name_clash")

    output = SpecSupport.run!(["-c", "-z", "1", "spec/fixtures/test_dir2"])
    output.should contain("dir_name_clash")
  end
end
