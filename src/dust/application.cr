require "./cli"
require "./input_paths"
require "./result_presenter"
require "./scan"
require "./walker/runtime_errors"

module Dust
  # Coordinates one invocation while delegating each phase to a focused object.
  class Application
    def initialize(@input : IO = STDIN, @output : IO = STDOUT, @error : IO = STDERR)
    end

    def run(argv : Array(String)) : Int32
      options = CLI::Parser.new(@output, @error).parse(argv)
      paths = Inputs.new(options, @input, @error).resolve
      result = Scanner.new(options, @error).call(paths)

      Reporter.new(@error).report(result.errors, options.print_errors?)
      return 1 if result.tree.children.empty? && !result.errors.missing.empty?

      Presenter.new(options, @output).render(result.tree)
      0
    end
  end
end
