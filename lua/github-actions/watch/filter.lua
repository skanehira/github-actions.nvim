---@class WatchableRun
---@field databaseId number Run ID
---@field status string Status ("in_progress" | "queued" | "waiting" | "pending" | "requested" | "completed" | ...)
---@field headBranch string Branch name
---@field displayTitle string Run title
---@field createdAt string Created timestamp (ISO 8601)

local M = {}

-- Statuses where a workflow run is still active (not in a terminal state).
-- GitHub REST API returns all five for non-completed runs; `gh run watch`
-- accepts all of them.
M.ACTIVE_STATUSES = {
  in_progress = true,
  queued = true,
  waiting = true,
  pending = true,
  requested = true,
}
local ACTIVE_STATUSES = M.ACTIVE_STATUSES

---Filter running workflows
---@param runs WatchableRun[]? All workflow runs
---@return WatchableRun[] Running workflow runs (sorted by creation time, newest first)
function M.filter_running_runs(runs)
  if not runs or #runs == 0 then
    return {}
  end

  local running = {}
  for _, run in ipairs(runs) do
    if ACTIVE_STATUSES[run.status] then
      table.insert(running, run)
    end
  end

  -- Sort by createdAt descending (newest first)
  table.sort(running, function(a, b)
    return a.createdAt > b.createdAt
  end)

  return running
end

return M
