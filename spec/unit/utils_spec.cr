require "../spec_helper"

require "../../src/dust/utils"

module SpecSupport::Paths
  extend self

  # `simplify` returns a set; the specs compare sorted arrays.
  def simplify(dirs : Array(String)) : Array(String)
    Dust::Utils.simplify(dirs).to_a.sort
  end
end

describe Dust::Utils do
  describe "#normalize" do
    it "drops repeated separators and dot components" do
      Dust::Utils.normalize("a/b").should eq("a/b")
      Dust::Utils.normalize("a/b//").should eq("a/b")
      Dust::Utils.normalize("a/././b///").should eq("a/b")
      Dust::Utils.normalize("c/.").should eq("c")
      Dust::Utils.normalize("src/.").should eq("src")
      Dust::Utils.normalize("/usr//local/./bin").should eq("/usr/local/bin")
      Dust::Utils.normalize("/").should eq("/")
      Dust::Utils.normalize(".").should eq(".")
      Dust::Utils.normalize("./").should eq(".")
      Dust::Utils.normalize("././").should eq(".")
      Dust::Utils.normalize("").should eq("")
    end

    it "keeps parent components" do
      Dust::Utils.normalize("a/../b").should eq("a/../b")
    end
  end

  describe "#join" do
    it "joins like Path::join" do
      Dust::Utils.join("a", "b").should eq("a/b")
      Dust::Utils.join("a/", "b").should eq("a/b")
      Dust::Utils.join("a", "").should eq("a")
      Dust::Utils.join("", "a").should eq("a")
    end

    it "lets an absolute child replace the parent" do
      Dust::Utils.join("a", "/b").should eq("/b")
    end
  end

  describe "#parent?" do
    it "knows ancestors" do
      Dust::Utils.parent?("/usr", "/usr/andy").should be_true
      Dust::Utils.parent?("/usr", "/usr/andy/i/am/descendant").should be_true
      Dust::Utils.parent?("/", "/usr/andy").should be_true
      Dust::Utils.parent?("/", "/usr").should be_true
    end

    it "rejects non ancestors" do
      Dust::Utils.parent?("/usr", "/usr/.").should be_false
      Dust::Utils.parent?("/usr", "/usr/").should be_false
      Dust::Utils.parent?("/usr", "/usr").should be_false
      Dust::Utils.parent?("/usr/", "/usr").should be_false
      Dust::Utils.parent?("/usr/andy", "/usr").should be_false
      Dust::Utils.parent?("/usr/andy", "/usr/sibling").should be_false
      Dust::Utils.parent?("/usr/folder", "/usr/folder_not_a_child").should be_false
      Dust::Utils.parent?("/", "/").should be_false
    end
  end

  describe "#simplify" do
    it "keeps a single directory" do
      SpecSupport::Paths.simplify(["a"]).should eq(["a"])
      SpecSupport::Paths.simplify(["."]).should eq(["."])
      SpecSupport::Paths.simplify(["./"]).should eq(["."])
    end

    it "removes subdirectories of other entries" do
      SpecSupport::Paths.simplify(["a/b/c", "a/b", "a/b/d/f"]).should eq(["a/b"])
      SpecSupport::Paths.simplify(["a/b", "a/b/c", "a/b/d/f"]).should eq(["a/b"])
    end

    it "removes duplicates" do
      SpecSupport::Paths.simplify(["a/b", "a/b//", "a/././b///", "c", "c/", "c/.", "c/././", "c/././."]).should eq(["a/b", "c"])
    end

    it "removes subdirectories without touching substrings" do
      SpecSupport::Paths.simplify(["a/b", "c/a/b/", "b"]).should eq(["a/b", "b", "c/a/b"])
      SpecSupport::Paths.simplify(["src/", "src_v2"]).should eq(["src", "src_v2"])
    end
  end

  describe "regex filters" do
    it "keeps only matching files when a filter is set" do
      regexes = [/test_dir/]
      Dust::Utils.unmatched?(regexes, "a/test_dir2").should be_false
      Dust::Utils.unmatched?(regexes, "a/other").should be_true
    end

    it "treats an empty filter list as no filter" do
      Dust::Utils.unmatched?([] of Regex, "a/other").should be_false
    end

    it "drops files matching the invert filter" do
      regexes = [/\.png$/]
      Dust::Utils.excluded?(regexes, "a/b.png").should be_true
      Dust::Utils.excluded?(regexes, "a/b.txt").should be_false
    end
  end
end
