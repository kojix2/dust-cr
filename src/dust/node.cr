module Dust
  class Node
    include Comparable(Node)

    # File nodes share this immutable empty list instead of allocating one each.
    EMPTY = [] of Node

    getter name : String
    getter size : UInt64
    getter inode_device : FileId?
    getter depth : Int32

    def initialize(@name : String, @size : UInt64, @children : Array(Node)?,
                   @inode_device : FileId?, @depth : Int32)
    end

    def children : Array(Node)
      @children || EMPTY
    end

    def <=>(other : Node) : Int32
      return size <=> other.size unless size == other.size
      return name <=> other.name unless name == other.name
      compare_children(children, other.children)
    end

    def total! : Nil
      @size += children.sum(&.size)
    end

    private def compare_children(a : Array(Node), b : Array(Node)) : Int32
      count = Math.min(a.size, b.size)
      count.times do |index|
        result = a[index] <=> b[index]
        return result unless result == 0
      end
      a.size <=> b.size
    end
  end
end
