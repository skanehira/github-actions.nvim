local api = require('github-actions.history.api')
local filter = require('github-actions.watch.filter')

local M = {}

-- gh workflow run does not return a run ID, and the new run takes a few
-- seconds to appear in gh run list. Poll until it shows up.
local DEFAULT_MAX_ATTEMPTS = 5
local DEFAULT_INTERVAL_MS = 2000

---@class PollOptions
---@field max_attempts? integer Maximum fetch attempts (default: 5)
---@field interval_ms? integer Interval between attempts in milliseconds (default: 2000)

---Poll runs of a workflow until a running run appears or attempts run out
---The callback receives running runs (empty when none found after all attempts) or an error
---@param workflow_file string Workflow filename (e.g., "ci.yml")
---@param opts? PollOptions
---@param callback fun(running_runs: WatchableRun[]|nil, err: string|nil)
function M.poll_running_runs(workflow_file, opts, callback)
  opts = opts or {}
  local max_attempts = opts.max_attempts or DEFAULT_MAX_ATTEMPTS
  local interval_ms = opts.interval_ms or DEFAULT_INTERVAL_MS

  local attempt = 0
  local function try_fetch()
    attempt = attempt + 1
    api.fetch_runs(workflow_file, function(runs, err)
      if err then
        callback(nil, err)
        return
      end

      local running_runs = filter.filter_running_runs(runs)
      if #running_runs > 0 then
        callback(running_runs, nil)
        return
      end

      if attempt >= max_attempts then
        callback({}, nil)
        return
      end

      vim.defer_fn(try_fetch, interval_ms)
    end)
  end

  try_fetch()
end

return M
