require "file_utils"

module SpecSupport
  # Yields a private temporary directory and always removes it afterwards.
  def self.temp_dir(prefix : String = "dust-cr", &)
    dir = File.tempname(prefix)
    FileUtils.mkdir_p(dir)
    begin
      yield dir
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
