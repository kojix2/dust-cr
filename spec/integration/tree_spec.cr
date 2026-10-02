require "./spec_helper"

describe "tree output" do
  it "prints a basic tree" do
    output = SpecSupport.run!(["-c", SpecSupport.fixture("test_dir/")])
    output.should contain(" ┌─┴ ")
    output.should contain("test_dir ")
    output.should contain("  ┌─┴ ")
    output.should contain("many ")
    output.should contain("    ├── ")
    output.should contain("hello_file")
    output.should contain("     ┌── ")
    output.should contain("a_file ")
  end

  it "does not print excess spaces without bars" do
    output = SpecSupport.run!(["-b", "-c", SpecSupport.fixture("test_dir/")])
    output.should contain("many")
    output.should_not contain("many    ")
  end

  it "reverses the order with -r" do
    output = SpecSupport.run!(["-r", "-c", SpecSupport.fixture("test_dir/")])
    output.should contain(" └─┬ test_dir ")
    output.should contain("  └─┬ many ")
    output.should contain("    ├── hello_file")
    output.should contain("    └── a_file ")
  end

  it "limits the depth with -d" do
    output = SpecSupport.run!(["-d", "1", "-c", SpecSupport.fixture("test_dir/")])
    output.should_not contain("hello_file")
  end

  it "handles -d 0 with several arguments" do
    output = SpecSupport.run!(["-d", "0", "-c", SpecSupport.fixture("test_dir/"),
                               SpecSupport.fixture("test_dir2")])
    output.should contain("test_dir ")
    output.should contain("test_dir2")
  end

  it "accepts -T" do
    output = SpecSupport.run!(["-T", "1", "-c", SpecSupport.fixture("test_dir/")])
    output.should contain("hello_file")
  end

  it "still recurses down with -d 1 and -f" do
    output = SpecSupport.run!(["-d", "1", "-f", "-c", SpecSupport.fixture("test_dir2/")])
    output.should contain("1   ┌── dir")
    output.should contain("4 ┌─┴ test_dir2")
  end

  it "shows hidden files by default and hides them with -i" do
    path = SpecSupport.fixture("test_dir_hidden_entries/")
    output = SpecSupport.run!(["-c", path])
    output.should contain(".hidden_file")
    output.should contain("┌─┴ test_dir_hidden_entries")

    output = SpecSupport.run!(["-c", "-i", path])
    output.should_not contain(".hidden_file")
    output.should contain("┌── test_dir_hidden_entries")
  end

  it "counts files with -f" do
    output = SpecSupport.run!(["-c", "-f", SpecSupport.fixture("test_dir")])
    output.should contain("1     ┌── a_file ")
    output.should contain("1     ├── hello_file")
    output.should contain("2   ┌─┴ many")
    output.should contain("2 ┌─┴ test_dir")
  end

  it "shows only files with -F" do
    output = SpecSupport.run!(["-c", "-F", SpecSupport.fixture("test_dir")])
    output.should contain("a_file")
    output.should contain("hello_file")
    output.should_not contain("many")
  end

  it "hides the total row with --skip-total" do
    output = SpecSupport.run!(["--skip-total", SpecSupport.fixture("test_dir/many/hello_file"),
                               SpecSupport.fixture("test_dir/many/a_file")])
    output.should contain("hello_file")
    output.should_not contain("(total)")
  end

  it "drops bars and adds a depth column with -R" do
    output = SpecSupport.run!(["--screen-reader", "-c", SpecSupport.fixture("test_dir/")])
    output.should contain("test_dir   0")
    output.should contain("many       1")
    output.should contain("hello_file 2")
    output.should contain("a_file     2")
    output.should_not contain('│')
    output.should_not contain('█')
    output.should_not contain('▓')
    output.should_not contain('▒')
    output.should_not contain('░')
  end

  it "keeps a directory collapsed with --collapse" do
    output = SpecSupport.run!(["--collapse", "many", SpecSupport.fixture("test_dir/")])
    output.should contain("many")
    output.should_not contain("hello_file")
  end

  it "disambiguates duplicate top level names" do
    output = SpecSupport.run!(["-c", SpecSupport.fixture("test_dir_matching/dave/dup_name"),
                               SpecSupport.fixture("test_dir_matching/andy/dup_name")])
    output.should contain("andy")
    output.should contain("dave")
    output.should contain("dup_name")
    output.should_not contain("test_dir_matching")
  end
end
