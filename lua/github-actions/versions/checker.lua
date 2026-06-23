---@class WorkflowChecker
local M = {}

local parser = require('github-actions.versions.parser')
local github = require('github-actions.shared.github')
local semver = require('github-actions.lib.semver')
local cache = require('github-actions.versions.cache')

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
    local status = semver.get_version_status(action.version, latest_version)

    if status == 'newer' then
      -- Current version is newer than latest - treat as error
      version_info.error = 'newer than latest'
      version_info.is_latest = false
    elseif status == 'latest' then
      version_info.is_latest = true
    else -- 'outdated' or 'invalid'
      version_info.is_latest = false
    end
  end

  return version_info
end

---Check version information for a buffer (business logic only)
---@param bufnr number Buffer number
---@param callback fun(version_infos: VersionInfo[]|nil, error: string|nil)
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
  -- Group uncached actions by cache_key so multiple uses of the same owner/repo
  -- share a single API call. Without this, a workflow with N references to
  -- actions/checkout fires N requests against GitHub for the same data.
  local api_call_groups = {} -- cache_key -> { owner, repo, actions = {...} }
  local api_call_keys = {} -- ordered list of cache_keys

  -- First pass: collect cached versions and prepare API call groups
  for _, action in ipairs(actions) do
    local cache_key = cache.make_key(action.owner, action.repo)

    if cache.has(cache_key) then
      local cached_version = cache.get(cache_key)
      table.insert(version_infos, create_version_info(action, cached_version, nil))
    else
      if not api_call_groups[cache_key] then
        api_call_groups[cache_key] = {
          owner = action.owner,
          repo = action.repo,
          actions = {},
        }
        table.insert(api_call_keys, cache_key)
      end
      table.insert(api_call_groups[cache_key].actions, action)
    end
  end

  -- If all versions were cached (no async API calls), invoke callback synchronously
  if #api_call_keys == 0 then
    callback(version_infos, nil)
    return
  end

  -- Track pending API calls (one per unique owner/repo, not per usage)
  local pending_count = #api_call_keys

  -- Second pass: execute one API call per group
  for _, cache_key in ipairs(api_call_keys) do
    local group = api_call_groups[cache_key]

    github.fetch_latest_release(group.owner, group.repo, function(latest_version, error_msg)
      if latest_version and not error_msg then
        cache.set(cache_key, latest_version)
      end

      -- Produce a version_info for every action in this group
      for _, action in ipairs(group.actions) do
        table.insert(version_infos, create_version_info(action, latest_version, error_msg))
      end

      pending_count = pending_count - 1

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
