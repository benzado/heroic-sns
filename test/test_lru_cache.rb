require 'test/unit'
require 'heroic/lru_cache'

class LRUCacheTest < Test::Unit::TestCase

  def test_invalid_size
    assert_raises ArgumentError do
      Heroic::LRUCache.new(0) { |k| nil }
    end
    assert_raises ArgumentError do
      Heroic::LRUCache.new(-1) { |k| nil }
    end
  end

  def test_get_put
    cache = Heroic::LRUCache.new(1)
    assert_nil cache.get(:foo)
    cache.put(:foo, :bar)
    assert_equal :bar, cache.get(:foo)
    cache.put(:answer, 42)
    assert_equal 42, cache.get(:answer)
    assert_nil cache.get(:foo)
  end

  def test_exceptions
    @should_throw = true
    cache = Heroic::LRUCache.new(3) do |k|
      if @should_throw
        raise "tried to load a value but failed"
      else
        4
      end
    end
    assert_raises RuntimeError do
      cache.get(:foo)
    end
    @should_throw = false
    assert_equal 4, cache.get(:foo)
  end

  def test_dynamic
    @counter = 0
    cache = Heroic::LRUCache.new(3) { |k| @counter += 1; "hello, #{k}." }
    assert_equal 0, @counter
    cache.verify!
    assert_equal "hello, leo.", cache.get(:leo); assert_equal 1, @counter
    cache.verify!
    assert_equal "hello, leo.", cache.get(:leo); assert_equal 1, @counter
    cache.verify!
    assert_equal "hello, donnie.", cache.get(:donnie); assert_equal 2, @counter
    cache.verify!
    assert_equal "hello, donnie.", cache.get(:donnie); assert_equal 2, @counter
    cache.verify!
    assert_equal "hello, mikey.", cache.get(:mikey); assert_equal 3, @counter
    cache.verify!
    assert_equal "hello, mikey.", cache.get(:mikey); assert_equal 3, @counter
    cache.verify!
    # raph will push leo out of cache
    assert_equal "hello, raph.", cache.get(:raph); assert_equal 4, @counter
    cache.verify!
    assert_equal "hello, raph.", cache.get(:raph); assert_equal 4, @counter
    cache.verify!
    # mikey and donnie remain in cache
    assert_equal "hello, mikey.", cache.get(:mikey); assert_equal 4, @counter
    cache.verify!
    assert_equal "hello, donnie.", cache.get(:donnie); assert_equal 4, @counter
    cache.verify!
    # leo will have to be refetched
    assert_equal "hello, leo.", cache.get(:leo); assert_equal 5, @counter
    cache.verify!
  end

  def test_sync
    @lock = Mutex.new
    @counter = 0
    cache = Heroic::LRUCache.new(100) do |k|
      sleep 1 # simulate slow generation, such as network I/O
      @lock.synchronize { @counter += 1 }
      k.to_s
    end
    # load the cache with things to read
    cache.put(:a, 'a')
    cache.put(:b, 'b')
    cache.put(:c, 'c')
    start_time = Time.now
    # start fetch in background
    td = Thread.new do
      cache.get(:d)
    end
    te = Thread.new do
      cache.get(:e)
    end
    # while background threads fetch, reading other keys should not be blocked
    assert_equal 'a', cache.get(:a)
    assert_equal 'b', cache.get(:b)
    assert_equal 'c', cache.get(:c)
    assert_equal 0, @lock.synchronize { @counter }
    # now main thread should block until background items are fetched
    assert_equal "d", cache.get(:d)
    assert_equal "e", cache.get(:e)
    assert_equal 2, @lock.synchronize { @counter }
    # reading the same values should be fast (they are cached)
    assert_equal "d", cache.get(:d)
    assert_equal "e", cache.get(:e)
    assert_equal 2, @lock.synchronize { @counter }
    # look at time elapsed to make sure we didn't sleep more than once
    [td, te].each { |t| t.join }
    time_elapsed = (Time.now - start_time)
    assert_in_delta time_elapsed, 1.0, 0.01
  end

end
