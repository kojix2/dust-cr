module SpecSupport::Walk
  record Result, nodes : Array(Dust::Node), errors : Dust::Errors

  extend self

  def run(dir : String, **options) : Result
    walker = Dust::Walker.new(**options)
    Result.new(walker.walk(Set(String).new([dir]), 2), walker.errors)
  end

  def count(node : Dust::Node) : Int32
    1 + node.children.sum { |child| count(child) }
  end

  def depth(node : Dust::Node) : Int32
    node.children.reduce(node.depth) do |deepest, child|
      Math.max(deepest, depth(child))
    end
  end
end
