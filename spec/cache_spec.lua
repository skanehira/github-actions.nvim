-- Test for cache module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

describe('cache', function()
  ---@type Cache
  local cache = require('github-actions.cache')

  before_each(function()
    -- Clear cache before each test
    cache.clear()
  end)

  describe('get and set', function()
    it('should store and retrieve version info', function()
      local key = 'actions/checkout'
      local version = 'v5.0.0'

      cache.set(key, version)
      local result = cache.get(key)

      assert.equals(version, result)
    end)

    it('should return nil for non-existent key', function()
      local result = cache.get('non-existent/action')
      assert.is_nil(result)
    end)

    it('should overwrite existing value', function()
      local key = 'actions/setup-node'

      cache.set(key, 'v3.0.0')
      cache.set(key, 'v4.0.0')

      local result = cache.get(key)
      assert.equals('v4.0.0', result)
    end)
  end)

  describe('has', function()
    it('should return true for existing key', function()
      cache.set('actions/cache', 'v4.0.0')
      assert.is_true(cache.has('actions/cache'))
    end)

    it('should return false for non-existent key', function()
      assert.is_false(cache.has('actions/missing'))
    end)
  end)

  describe('clear', function()
    it('should clear all cached data', function()
      cache.set('actions/checkout', 'v5.0.0')
      cache.set('actions/setup-node', 'v4.0.0')

      cache.clear()

      assert.is_false(cache.has('actions/checkout'))
      assert.is_false(cache.has('actions/setup-node'))
    end)
  end)

  describe('make_key', function()
    it('should create key from owner and repo', function()
      local key = cache.make_key('actions', 'checkout')
      assert.equals('actions/checkout', key)
    end)

    it('should handle different owners', function()
      local key1 = cache.make_key('actions', 'setup-node')
      local key2 = cache.make_key('docker', 'setup-node')

      assert.equals('actions/setup-node', key1)
      assert.equals('docker/setup-node', key2)
      assert.not_equal(key1, key2)
    end)
  end)
end)
