require "json"
require "./size_format"

module Dust
  # The tree that gets rendered. Field order matters: `Ord` compares
  # (size, name, children) lexicographically, exactly like the Rust struct.
  class DisplayNode
    include Comparable(DisplayNode)

    # Leaf nodes share this immutable empty list instead of allocating one each.
    EMPTY = [] of DisplayNode

    getter size : UInt64
    getter name : String

    def initialize(@size : UInt64, @name : String, @children : Array(DisplayNode)?)
    end

    def children : Array(DisplayNode)
      @children || EMPTY
    end

    def num_siblings : UInt64
      children.size.to_u64
    end

    def ordered_children(is_reversed : Bool) : Array(DisplayNode)
      is_reversed ? children.reverse : children
    end

    def <=>(other : DisplayNode) : Int32
      return size <=> other.size unless size == other.size
      return name <=> other.name unless name == other.name
      count = Math.min(children.size, other.children.size)
      count.times do |index|
        result = children[index] <=> other.children[index]
        return result unless result == 0
      end
      children.size <=> other.children.size
    end

    # `size` is a pre-formatted string so that `-o` also applies to JSON output.
    def to_json(io : IO) : Nil
      to_json(io, "")
    end

    def to_json(output_type : String) : String
      String.build { |io| to_json(io, output_type) }
    end

    def to_json(io : IO, output_type : String) : Nil
      size = SizeFormat.humanize(@size, output_type)
      io << '{'
      io << "\"size\":"
      size.to_json(io)
      io << ",\"name\":"
      @name.to_json(io)
      io << ",\"children\":["
      children.each_with_index do |child, index|
        io << ',' unless index == 0
        child.to_json(io, output_type)
      end
      io << ']'
      io << '}'
    end
  end
end
