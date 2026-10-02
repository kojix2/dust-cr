require "../spec_helper"

require "../../src/dust/dir_walker"
require "../support/files"
require "../support/walk"

# Ported from the walker unit tests in dust's src/dir_walker.rs.
describe Dust::Walker do
  it "walks a deeply nested tree without recursion" do
    depth = 100

    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      path = dir
      depth.times do
        path = File.join(path, "a")
        Dir.mkdir(path)
      end

      result = SpecSupport::Walk.run(dir)
      result.nodes.size.should eq(1)
      SpecSupport::Walk.depth(result.nodes[0]).should eq(depth)
      # Root plus depth descendants, each holding exactly one child.
      SpecSupport::Walk.count(result.nodes[0]).should eq(depth + 1)
    end
  end

  it "walks a directory with many siblings" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      500.times { |index| File.write(File.join(dir, "f#{index}"), index.to_s) }

      result = SpecSupport::Walk.run(dir)
      result.nodes.size.should eq(1)
      result.nodes[0].children.size.should eq(500)
      SpecSupport::Walk.count(result.nodes[0]).should eq(501)
    end
  end

  it "counts hard linked files once" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      File.write(File.join(dir, "notes.txt"), "I am a temp file\n")
      Process.run("ln", [File.join(dir, "notes.txt"), File.join(dir, "the_link")])

      result = SpecSupport::Walk.run(dir)
      result.nodes[0].children.size.should eq(1)

      # With apparent size the deduplication is deliberately skipped.
      result = SpecSupport::Walk.run(dir, apparent: true)
      result.nodes[0].children.size.should eq(2)
    end
  end

  it "does not retain the inode of a singly linked file" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      File.write(File.join(dir, "one"), "x")

      result = SpecSupport::Walk.run(dir)
      result.nodes[0].children[0].inode_device.should be_nil
    end
  end

  it "counts a followed symlink alias once" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      file = File.join(dir, "one")
      File.write(file, "x")
      Process.run("ln", ["-s", file, File.join(dir, "link")])

      result = SpecSupport::Walk.run(dir, follow_links: true)
      result.nodes[0].children.size.should eq(1)
    end
  end

  it "records a missing root" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      missing = File.join(dir, "does-not-exist")
      result = SpecSupport::Walk.run(missing)
      result.errors.missing.should contain(missing)
    end
  end

  it "records directories it may not read" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      locked = File.join(dir, "locked")
      Dir.mkdir(locked)
      File.chmod(locked, 0o000)

      # Skipped when running as root: mode bits do not deny root.
      if Dir.exists?(locked) && (Dir.entries(locked).size > 0 rescue false)
        File.chmod(locked, 0o755)
      else
        result = SpecSupport::Walk.run(dir)
        File.chmod(locked, 0o755)
        result.errors.denied.should contain(locked)
      end
    end
  end

  it "ignores hidden files when asked" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      File.write(File.join(dir, ".hidden"), "x")
      File.write(File.join(dir, "shown"), "y")

      result = SpecSupport::Walk.run(dir)
      result.nodes[0].children.size.should eq(2)

      result = SpecSupport::Walk.run(dir, hide_hidden: true)
      result.nodes[0].children.size.should eq(1)
      result.nodes[0].children[0].name.ends_with?("shown").should be_true
    end
  end

  it "ignores directories named with -X" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      Dir.mkdir(File.join(dir, "skip"))
      File.write(File.join(dir, "skip", "inner"), "x")
      File.write(File.join(dir, "kept"), "y")

      result = SpecSupport::Walk.run(dir, ignored: Set(String).new([File.join(dir, "skip")]))
      result.nodes[0].children.size.should eq(1)
      result.nodes[0].children[0].name.ends_with?("kept").should be_true
    end
  end

  it "keeps a file target but drops everything else when filtering" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      File.write(File.join(dir, "keep.rs"), "x")
      File.write(File.join(dir, "drop.txt"), "y")

      result = SpecSupport::Walk.run(dir, filters: [/keep\.rs$/])
      result.nodes[0].children.size.should eq(1)
      result.nodes[0].children[0].name.ends_with?("keep.rs").should be_true
      # A filtered out file still takes up space on disk.
      result.nodes[0].children[0].size.should be > 0
    end
  end

  it "counts files instead of bytes" do
    SpecSupport.temp_dir("dust-cr-walker") do |dir|
      File.write(File.join(dir, "a"), "1234567890")
      File.write(File.join(dir, "b"), "1234567890")
      Dir.mkdir(File.join(dir, "sub"))
      File.write(File.join(dir, "sub", "c"), "x")

      result = SpecSupport::Walk.run(dir, count_files: true, apparent: true)
      # The directory inode itself counts as zero, its two files as one each,
      # and the subdirectory adds up to one.
      result.nodes[0].size.should eq(3)
      result.nodes[0].children.all? { |child| child.size == 1 }.should be_true
    end
  end
end
