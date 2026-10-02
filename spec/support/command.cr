module SpecSupport
  BIN = File.join(Dir.tempdir, "dust-cr-spec-bin")

  record Result, output : String, error : String, exit_code : Int32 do
    def success? : Bool
      exit_code == 0
    end
  end

  extend self

  def fixture(path : String) : String
    File.join(FIXTURES, path)
  end

  def run(args : Array(String), input : String? = nil) : Result
    command = [build, "-P", *args]
    output = IO::Memory.new
    error = IO::Memory.new
    stdin = input ? IO::Memory.new(input) : Process::Redirect::Close
    status = Process.run(command, input: stdin, output: output, error: error, chdir: PROJECT)

    Result.new(output.to_s, error.to_s, status.exit_code)
  end

  def run!(args : Array(String), input : String? = nil) : String
    result = run(args, input)
    raise "dust #{args.join(" ")} failed:\n#{result.error}" unless result.success?
    result.output
  end

  private def build : String
    source = File.join(PROJECT, "src", "dust.cr")

    if File.exists?(BIN)
      built_at = File.info(BIN).modification_time
      newest = Dir.glob(File.join(PROJECT, "src", "**", "*.cr")).max_of do |path|
        File.info(path).modification_time
      end
      return BIN if newest <= built_at
    end

    status = Process.run("crystal", "build", "--release", source, "-o", BIN,
      output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    raise "failed to build dust: #{status.exit_code}" unless status.success?

    BIN
  end
end
