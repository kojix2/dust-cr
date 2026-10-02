require "./spec_helper"
require "../support/files"

# Ported from dust's tests/tests_symlinks.rs.
describe "dust symlinks" do
  it "shows a soft link as a file" do
    SpecSupport.temp_dir do |dir|
      File.write(File.join(dir, "notes.txt"), "I am a temp file\n")
      Process.run("ln", ["-s", File.join(dir, "notes.txt"), File.join(dir, "the_link")])

      output = SpecSupport.run!(["-p", "-c", "-s", "-w", "999", dir])
      output.should contain("─┴ #{dir}")
      output.should contain(" ┌── #{File.join(dir, "notes.txt")}")
      output.should contain(" ├── #{File.join(dir, "the_link")}")
    end
  end

  it "counts a hard linked file only once" do
    SpecSupport.temp_dir do |dir|
      File.write(File.join(dir, "notes.txt"), "I am a temp file\n")
      Process.run("ln", [File.join(dir, "notes.txt"), File.join(dir, "the_link")])

      output = SpecSupport.run!(["-p", "-c", "-w", "999", dir])
      output.should contain("─┴ #{dir}")
      output.should contain(" ┌── #{File.join(dir, "notes.txt")}")
      output.should_not contain(File.join(dir, "the_link"))
    end
  end

  it "counts a hard link in another directory only once" do
    SpecSupport.temp_dir do |first|
      SpecSupport.temp_dir do |second|
        File.write(File.join(first, "notes.txt"), "I am a temp file\n")
        Process.run("ln", [File.join(first, "notes.txt"), File.join(second, "the_link")])

        output = SpecSupport.run!(["-p", "-c", "-w", "999", "-b", second, first])
        appearances = [File.join(first, "notes.txt"), File.join(second, "the_link")].count do |path|
          output.includes?(path)
        end
        # Whichever of the two survives the deduplication, only one may show up.
        appearances.should eq(1)
      end
    end
  end

  it "does not loop on a recursive symlink" do
    SpecSupport.temp_dir do |dir|
      File.write(File.join(dir, "notes.txt"), "I am a temp file\n")
      Process.run("ln", ["-s", dir, File.join(dir, "the_link")])

      output = SpecSupport.run!(["-p", "-c", "-r", "-s", "-w", "999", dir])
      output.should contain("─┬ #{dir}")
      output.should contain(File.join(dir, "the_link"))
      # The link points at its own parent: it must be counted, not followed.
      output.should_not contain(File.join(dir, "the_link/notes.txt"))
    end
  end

  it "follows links with -L" do
    SpecSupport.temp_dir do |outer|
      SpecSupport.temp_dir do |inner|
        File.write(File.join(inner, "notes.txt"), "I am a temp file\n")
        Process.run("ln", ["-s", inner, File.join(outer, "the_link")])

        output = SpecSupport.run!(["-p", "-c", "-L", "-s", "-w", "999", outer])
        output.should contain(File.join(outer, "the_link/notes.txt"))
      end
    end
  end
end
