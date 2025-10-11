---@class WorkflowChecker
local M = {}

local parser = require('github-actions.workflow.parser')
local github = require('github-actions.github')
local semver = require('github-actions.lib.semver')
local cache = require('github-actions.cache')

---Create version info from action and latest version
---@param action Action Parsed action usage from workflow
---@param latest_version string|nil Latest version from GitHub API
---@param error_msg string|nil Error message if version check failed
---@return VersionInfo version_info Version information for display
local function create_version_info(action, latest_version, error_msg)
  ---@type VersionInfo
  local version_info = {
    line = action.line,
    col = action.col,
    current_version = action.version,
    latest_version = latest_version,
    is_latest = false,
    error = error_msg,
  }

  if not error_msg and latest_version and action.version then
    version_info.is_latest = semver.compare(action.version, latest_version)
  end

  return version_info
end

---Check version information for a buffer (business logic only)
---@param bufnr number Buffer number
---@param callback function Callback function(version_infos, error)
function M.check_versions(bufnr, callback)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    callback(nil, 'Invalid buffer')
    return
  end

  -- Check if gh CLI is available
  if not github.is_available() then
    callback(nil, 'gh command not found. Please install GitHub CLI.')
    return
  end

  -- Parse workflow file
  local actions = parser.parse(bufnr)
  if #actions == 0 then
    callback({}, nil)
    return
  end

  local version_infos = {}
  local api_calls = {}

  -- First pass: collect cached versions and prepare API calls
  for _, action in ipairs(actions) do
    local cache_key = cache.make_key(action.owner, action.repo)

    -- Check if version is cached
    if cache.has(cache_key) then
      -- Use cached version
      local cached_version = cache.get(cache_key)
      local version_info = create_version_info(action, cached_version, nil)
      table.insert(version_infos, version_info)
    else
      -- Need to fetch from API - store for later
      table.insert(api_calls, action)
    end
  end

  -- If all versions were cached (no async API calls), invoke callback synchronously
  if #api_calls == 0 then
    callback(version_infos, nil)
    return
  end

  -- Track pending API calls
  local pending_count = #api_calls

  -- Second pass: execute all API calls
  for _, action in ipairs(api_calls) do
    local cache_key = cache.make_key(action.owner, action.repo)

    github.fetch_latest_release(action.owner, action.repo, function(latest_version, error_msg)
      -- Cache the version if successful
      if latest_version and not error_msg then
        cache.set(cache_key, latest_version)
      end

      -- Create version info
      local version_info = create_version_info(action, latest_version, error_msg)
      table.insert(version_infos, version_info)

      -- Decrement pending count
      pending_count = pending_count - 1

      -- When all async API calls complete, invoke callback
      if pending_count == 0 then
        -- vim.schedule is needed because this callback runs in vim.system's context
        vim.schedule(function()
          callback(version_infos, nil)
        end)
      end
    end)
  end
end

return M
