require "../spec_helper"

require "../../src/dust/size_format"

module SpecSupport::Size
  extend self

  def power(base : Int, exponent : Int) : Int64
    base.to_i64 ** exponent
  end

  def human(size : Int, format : String = "") : String
    Dust::SizeFormat.humanize(size.to_u64, format)
  end

  def parse(input : String) : UInt64?
    Dust::SizeFormat.parse_min(input)
  end
end

describe Dust::SizeFormat do
  describe "#humanize" do
    it "prints raw counts" do
      SpecSupport::Size.human(1, "count").should eq("1")
      SpecSupport::Size.human(1000, "count").should eq("1000")
      SpecSupport::Size.human(1024, "count").should eq("1024")
    end

    it "uses IEC units by default" do
      SpecSupport::Size.human(1).should eq("1B")
      SpecSupport::Size.human(956).should eq("956B")
      SpecSupport::Size.human(1004).should eq("1004B")
      SpecSupport::Size.human(1024).should eq("1.0Ki")
      SpecSupport::Size.human(1536).should eq("1.5Ki")
      SpecSupport::Size.human(1024 * 512).should eq("512Ki")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 2)).should eq("1.0Mi")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 3) - 1).should eq("1023Mi")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 3) * 20).should eq("20Gi")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 4)).should eq("1.0Ti")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 4) * 234).should eq("234Ti")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 5)).should eq("1.0Pi")
    end

    it "uses SI units with si" do
      SpecSupport::Size.human(1024 * 100).should eq("100Ki")
      SpecSupport::Size.human(1024 * 100, "si").should eq("102K")
    end

    it "forces a unit when asked" do
      SpecSupport::Size.human(1023, "b").should eq("1023B")
      SpecSupport::Size.human(1_000_000, "bytes").should eq("1000000B")
      SpecSupport::Size.human(1023, "kb").should eq("1K")
      SpecSupport::Size.human(1023, "k").should eq("0Ki")
      SpecSupport::Size.human(1023, "kib").should eq("0Ki")
      SpecSupport::Size.human(1024, "kib").should eq("1Ki")
      SpecSupport::Size.human(1024 * 512, "kib").should eq("512Ki")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 2), "kib").should eq("1024Ki")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 1) * 1000 * 1000 * 20, "kib").should eq("20000000Ki")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 2) * 1000 * 20, "mib").should eq("20000Mi")
      SpecSupport::Size.human(SpecSupport::Size.power(1024, 3) * 20, "gib").should eq("20Gi")
    end
  end

  describe "#parse_min" do
    it "parses bare byte counts" do
      SpecSupport::Size.parse("55").should eq(55_u64)
      SpecSupport::Size.parse("12344321").should eq(12344321_u64)
    end

    it "rejects nonsense" do
      SpecSupport::Size.parse("95RUBBISH").should be_nil
    end

    it "parses IEC and SI suffixes case insensitively" do
      SpecSupport::Size.parse("10Ki").should eq((10 * SpecSupport::Size.power(1024, 1)).to_u64)
      SpecSupport::Size.parse("10MiB").should eq((10 * SpecSupport::Size.power(1024, 2)).to_u64)
      SpecSupport::Size.parse("10M").should eq((10 * SpecSupport::Size.power(1024, 2)).to_u64)
      SpecSupport::Size.parse("10Mb").should eq((10 * SpecSupport::Size.power(1000, 2)).to_u64)
      SpecSupport::Size.parse("2Gi").should eq((2_i64 * SpecSupport::Size.power(1024, 3)).to_u64)
      SpecSupport::Size.parse("1KiB").should eq(1024_u64)
      SpecSupport::Size.parse("2KiB").should eq(2048_u64)
      SpecSupport::Size.parse("1kb").should eq(1000_u64)
      SpecSupport::Size.parse("2KB").should eq(2000_u64)
    end
  end
end
