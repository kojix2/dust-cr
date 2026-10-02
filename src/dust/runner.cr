require "./application"

module Dust
  # Runs one command invocation.
  def self.run(argv : Array(String)) : Int32
    Application.new.run(argv)
  end
end
