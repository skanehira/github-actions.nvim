---@class Cache
local M = {}

-- In-memory cache storage
-- Key format: "owner/repo" -> version string
local cache_store = {}

---Create a cache key from owner and repo
---@param owner string Repository owner (e.g., "actions")
---@param repo string Repository name (e.g., "checkout")
---@return string key Cache key in format "owner/repo"
function M.make_key(owner, repo)
  return string.format('%s/%s', owner, repo)
end

---Get cached version info
---@param key string Cache key
---@return string|nil version Cached version or nil if not found
function M.get(key)
  return cache_store[key]
end

---Set version info in cache
---@param key string Cache key
---@param version string Version to cache
function M.set(key, version)
  cache_store[key] = version
end

---Check if key exists in cache
---@param key string Cache key
---@return boolean exists True if key exists in cache
function M.has(key)
  return cache_store[key] ~= nil
end

---Clear all cached data
function M.clear()
  cache_store = {}
end

return M
