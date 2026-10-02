require "../node"

module Dust
  module WalkerSupport
    # A directory whose children may still be processed by other workers.
    class Pending
      getter dir : String
      getter depth : Int32
      getter? symlink : Bool
      getter parent : Pending?
      property own_node : Node? = nil

      def initialize(@dir : String, @depth : Int32, @symlink : Bool,
                     @parent : Pending? = nil)
        @children = [] of Node
        # One pending item represents completion of this directory's listing.
        @pending = 1
        @mutex = Thread::Mutex.new
      end

      def prepare(children : Array(Node), subdirs : Int32) : Nil
        @mutex.synchronize do
          @children = children
          @pending += subdirs
        end
      end

      def listed? : Bool
        @mutex.synchronize do
          @pending -= 1
          @pending == 0
        end
      end

      def child_finished(node : Node?) : Bool
        @mutex.synchronize do
          @children << node if node
          @pending -= 1
          @pending == 0
        end
      end

      def done_children : Array(Node)
        @mutex.synchronize { @children }
      end
    end
  end
end
