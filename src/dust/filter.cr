require "./display"
require "./display_node"
require "./node"

module Dust
  # Selects the largest nodes from a walked tree and rebuilds the portion that
  # should be displayed.
  class Pruner
    class Options
      getter min_size : UInt64?
      getter? only_dir : Bool
      getter? only_file : Bool
      getter lines : Int64
      getter depth : Int64
      getter? filtered : Bool
      getter? short_paths : Bool

      def initialize(@min_size : UInt64?, @only_dir : Bool, @only_file : Bool,
                     @lines : Int64, @depth : Int64,
                     @filtered : Bool, @short_paths : Bool)
      end
    end

    # Max heap over Nodes. Selection repeatedly takes the largest candidate, so
    # popping must remain O(log n) rather than scanning for the maximum.
    private class NodeHeap
      def initialize
        @items = [] of Node
      end

      def push(node : Node) : Nil
        @items << node
        sift_up(@items.size - 1)
      end

      def pop : Node?
        return if @items.empty?

        top = @items[0]
        last = @items.pop
        unless @items.empty?
          @items[0] = last
          sift_down(0)
        end
        top
      end

      private def sift_up(index : Int32) : Nil
        while index > 0
          parent = (index - 1) // 2
          break if (@items[parent] <=> @items[index]) >= 0

          @items[parent], @items[index] = @items[index], @items[parent]
          index = parent
        end
      end

      private def sift_down(index : Int32) : Nil
        size = @items.size
        loop do
          left = index * 2 + 1
          break if left >= size

          largest = left
          right = left + 1
          largest = right if right < size && (@items[right] <=> @items[left]) > 0
          break if (@items[index] <=> @items[largest]) >= 0

          @items[index], @items[largest] = @items[largest], @items[index]
          index = largest
        end
      end
    end

    def initialize(@options : Options, @collapsed : Set(String))
    end

    def call(roots : Array(Node)) : DisplayNode
      heap = NodeHeap.new

      root = case roots.size
             when 0
               total_node(0, [] of Node)
             when 1
               roots.first.tap { |node| add_children(node, heap) }
             else
               size = roots.sum(&.size)
               nodes = rename_roots(roots)
               total_node(size, nodes).tap { |node| add_all(node, heap) }
             end

      build_tree(heap, root)
    end

    private def total_node(size : UInt64, children : Array(Node)) : Node
      Node.new("(total)", size, children, nil, 0)
    end

    private def build_tree(heap : NodeHeap, root : Node) : DisplayNode
      selected = Hash(String, Node).new

      while selected.size < @options.lines
        node = heap.pop
        break unless node

        selected[node.name] = node if !@options.only_file? || node.children.empty?
        add_children(node, heap) unless @collapsed.includes?(node.name)
      end

      @options.only_file? ? flat_tree(selected, root) : rebuild_tree(selected, root)
    end

    private def add_children(node : Node, heap : NodeHeap) : Nil
      add_all(node, heap) if @options.depth > node.depth
    end

    private def add_all(node : Node, heap : NodeHeap) : Nil
      node.children.each do |child|
        keep = if min_size = @options.min_size
                 child.size > min_size
               else
                 !@options.filtered? || !File.directory?(child.name) || child.size > 0
               end
        next unless keep
        next if @options.only_dir? && !File.directory?(child.name)

        heap.push(child)
      end
    end

    private def rebuild_tree(selected : Hash(String, Node), current : Node) : DisplayNode
      children : Array(DisplayNode)? = nil
      current.children.each do |child|
        next unless selected.has_key?(child.name)

        children ||= [] of DisplayNode
        children << rebuild_tree(selected, child)
      end
      display_node(children, current)
    end

    private def flat_tree(selected : Hash(String, Node), root : Node) : DisplayNode
      children = Array(DisplayNode).new(selected.size)
      selected.each_value do |node|
        children << DisplayNode.new(node.size, node.name, nil)
      end

      display_node(children, root)
    end

    private def display_node(children : Array(DisplayNode)?, source : Node) : DisplayNode
      children.try &.sort! { |a, b| b <=> a }
      DisplayNode.new(source.size, source.name, children)
    end

    private def duplicates?(nodes : Array(Node)) : Bool
      names = Set(String).new

      nodes.each do |node|
        name = Display::Text.printable_name(node.name, true)
        return true if names.includes?(name)
        names.add(name)
      end

      false
    end

    # With several roots sharing a basename ("a/dup_name", "b/dup_name"),
    # append parent folders until the displayed names are unique.
    private def rename_roots(nodes : Array(Node)) : Array(Node)
      return nodes unless @options.short_paths? && duplicates?(nodes)

      renamed = nodes.dup
      parent_depth = 0

      while duplicates?(renamed) && parent_depth < 10
        parent_depth += 1
        renamed = renamed.map { |node| parent_name(node, parent_depth) }
      end

      renamed
    end

    private def parent_name(node : Node, parent_depth : Int32) : Node
      parts = node.name.split('/')
      index = parts.size - 1 - parent_depth
      return node if index < 0

      parent = parts[index]
      return node if parent.empty?

      Node.new("#{node.name}(#{parent})", node.size, node.children,
        node.inode_device, node.depth)
    end
  end
end
