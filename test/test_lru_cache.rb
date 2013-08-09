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
    assert_nil cache.get(:casey)
    cache.put(:casey, :jones)
    assert_equal :jones, cache.get(:casey)
    cache.put(:april, :oneil)
    assert_equal :oneil, cache.get(:april)
    assert_nil cache.get(:casey)
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
      cache.get(:ooze)
    end
    @should_throw = false
    assert_equal 4, cache.get(:ooze)
  end

  def test_dynamic
    @counter = 0
    cache = Heroic::LRUCache.new(3) { |k| @counter += 1; k.to_s.length }
    assert_equal 0, @counter
    cache.verify!
    assert_equal 3, cache.get(:leo); assert_equal 1, @counter
    cache.verify!
    assert_equal 3, cache.get(:leo); assert_equal 1, @counter
    cache.verify!
    assert_equal 6, cache.get(:donnie); assert_equal 2, @counter
    cache.verify!
    assert_equal 6, cache.get(:donnie); assert_equal 2, @counter
    cache.verify!
    assert_equal 5, cache.get(:mikey); assert_equal 3, @counter
    cache.verify!
    assert_equal 5, cache.get(:mikey); assert_equal 3, @counter
    cache.verify!
    # raph will push leo out of cache
    assert_equal 4, cache.get(:raph); assert_equal 4, @counter
    cache.verify!
    assert_equal 4, cache.get(:raph); assert_equal 4, @counter
    cache.verify!
    # mikey and donnie remain in cache
    assert_equal 5, cache.get(:mikey); assert_equal 4, @counter
    cache.verify!
    assert_equal 6, cache.get(:donnie); assert_equal 4, @counter
    cache.verify!
    # leo will have to be refetched
    assert_equal 3, cache.get(:leo); assert_equal 5, @counter
    cache.verify!
  end

  def test_sync
    @lock = Mutex.new
    @counter = 0
    cache = Heroic::LRUCache.new(100) do |k|
      sleep 1 # simulate slow generation, such as network I/O
      @lock.synchronize { @counter += 1 }
      k.to_s.length
    end
    # load the cache with things to read
    cache.put(:leo, 0)
    cache.put(:donnie, 0)
    start_time = Time.now
    # Start threads to fetch in background. :leo and :donnie should return
    # immediately, because the values are in the cache; :mikey and :raph should
    # run concurrently; the second :raph should wait on the first :raph to
    # complete.
    threads = [:leo, :donnie, :mikey, :raph, :raph].map do |k|
      Thread.new { cache.get(k) }
    end
    # Fetching values already in the cache should not block.
    assert_equal 0, cache.get(:leo)
    assert_equal 0, cache.get(:donnie)
    assert_equal 0, @lock.synchronize { @counter }
    # Fetching values being computed now will block until somebody computes them.
    assert_equal 5, cache.get(:mikey)
    assert_equal 4, cache.get(:raph)
    assert_equal 2, @lock.synchronize { @counter }
    # Fetching those same values should not trigger a recompute.
    assert_equal 5, cache.get(:mikey)
    assert_equal 4, cache.get(:raph)
    assert_equal 2, @lock.synchronize { @counter }
    # Let's wait for all threads to finish, then check the clock to make sure we
    # only slept for a second.
    threads.each { |t| t.join }
    time_elapsed = (Time.now - start_time)
    assert_in_delta time_elapsed, 1.0, 0.05
  end

end
