module Heroic

  # This LRU Cache is a generic key-value store that is designed to be safe for
  # concurrent access. It uses a doubly-linked-list to identify which item was
  # least recently retrieved, and a Hash for fast retrieval by key.

  # To support concurrent access, it uses two levels of locks: a cache-level lock
  # is used to locate or create the desired node and move it to the front of the
  # LRU list. A node-level lock is used to synchronize access to the node's
  # value.

  # If a thread is busy generating a value to be stored in the cache, other
  # threads will still be able to read and write to other keys with no conflict.
  # However, if a second thread tries to read the value that the first thread is
  # generating, it will block until the first thread has completed its work.

  class LRUCache

    class Node
      attr_reader :key
      attr_accessor :left, :right
      def initialize(key)
        @key = key
        @lock = Mutex.new
      end
      def read
        @lock.synchronize { @value ||= yield(@key) }
      end
      def write(value)
        @lock.synchronize { @value = value }
      end
      def to_s
        sprintf '<Node:%x(%s)>', self.object_id, @key.inspect
      end
    end

    # If you yield a block to the constructor, it will be called on every cache
    # miss to generate the needed value. This is optional but recommended, as
    # the block will run while holding a lock on the cache node associated with
    # the key. Additional attempts to retrieve the same key will wait for your
    # block to return a result, avoiding duplication of work. However, this also
    # means you MUST NOT access the cache itself from the block, or you will risk
    # creating deadlock. (If you need to create cacheable items from other
    # cacheable items, consider using two separate caches.)

    def initialize(capacity, &block)
      raise ArgumentError unless capacity > 0
      @capacity = capacity
      @block = block || Proc.new { nil }
      @lock = Mutex.new
      @store = Hash.new
      @leftmost = nil
      @rightmost = nil
    end

    def get(key)
      node = node_for_key(key)
      node.read(&@block)
    end

    def put(key, value)
      node = node_for_key(key)
      node.write(value)
    end

    def empty!
      @lock.synchronize do
        @store.empty!
        @leftmost = nil
        @rightmost = nil
      end
    end

    # Verify the list structure. Intended for testing and debugging only.
    def verify!
      @lock.synchronize do
        left_to_right = Array.new
        begin
          node = @leftmost
          while node
            left_to_right << node
            node = node.right
          end
        end
        right_to_left = Array.new
        begin
          node = @rightmost
          while node
            right_to_left << node
            node = node.left
          end
        end
        begin
          raise "leftmost has a left node" if @leftmost && @leftmost.left
          raise "rightmost has a right node" if @rightmost && @rightmost.right
          raise "leftmost pointer mismatch" unless @leftmost == left_to_right.first
          raise "rightmost pointer mismatch" unless @rightmost == right_to_left.first
          raise "list size mismatch" unless right_to_left.length == left_to_right.length
          raise "list order mismatch" unless left_to_right.reverse == right_to_left
          raise "node missing from list" if left_to_right.length < @store.size
          raise "node missing from store" if left_to_right.length > @store.size
          raise "store size exceeds capacity" if @store.size > @capacity
        rescue
          $stderr.puts "Store: #{@store}"
          $stderr.puts "L-to-R: #{left_to_right}"
          $stderr.puts "R-to-L: #{right_to_left}"
          raise
        end
      end
    end

    private

    def node_for_key(key)
      @lock.synchronize do
        node = @store[key]
        if node.nil?
          # I am a new node, add me to the head of the list!
          node = @store[key] = Node.new(key)
          if @leftmost
            node.right = @leftmost
            @leftmost.left = node
          end
          @leftmost = node
          @rightmost = @leftmost if @rightmost.nil?
          if @store.size > @capacity
            # Uh oh, time to evict the tail node!
            evicted_node = @store.delete(@rightmost.key)
            @rightmost = evicted_node.left
            @rightmost.right = nil
          end
        elsif node != @leftmost
          # Move me to the head of the list!
          if node == @rightmost
            # I was the rightmost node, now the node on my left is.
            @rightmost = node.left
            node.left.right = nil
          else
            # The node on my left should now point to the node on my right.
            node.left.right = node.right
            # The node on my right should point to the node on my left.
            node.right.left = node.left
          end
          former_leftmost = @leftmost
          # I am the new head node!
          @leftmost = node
          @leftmost.left = nil
          @leftmost.right = former_leftmost
          former_leftmost.left = @leftmost
        end
        node
      end
    end

  end
end
