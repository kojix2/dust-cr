require "./pending_directory"

module Dust
  module WalkerSupport
    # Unbounded work queue backed by a deque and a wakeup channel.
    class Queue
      @sleeping = 0

      def initialize
        @queue = Deque(Pending).new
        @mutex = Thread::Mutex.new
        @wakeup = Channel(Nil).new(1)
        @closed = false
      end

      def push(item : Pending) : Nil
        wake = @mutex.synchronize do
          @queue << item
          @sleeping > 0
        end
        @wakeup.send(nil) if wake
      end

      def close : Nil
        sleepers = @mutex.synchronize do
          @closed = true
          @sleeping
        end
        sleepers.times { @wakeup.send(nil) }
      end

      def pop : Pending?
        loop do
          item = nil
          closed = false

          @mutex.synchronize do
            if next_item = @queue.shift?
              item = next_item
            elsif @closed
              closed = true
            else
              @sleeping += 1
            end
          end

          return item if item
          return if closed

          @wakeup.receive
          @mutex.synchronize { @sleeping -= 1 }
        end
      end
    end
  end
end
