---@class WatchableRun
---@field databaseId number Run ID
---@field status string Status ("in_progress" | "queued" | "completed" | ...)
---@field headBranch string Branch name
---@field displayTitle string Run title
---@field createdAt string Created timestamp (ISO 8601)

local M = {}

---Filter running workflows
---@param runs WatchableRun[]? All workflow runs
---@return WatchableRun[] Running workflow runs (sorted by creation time, newest first)
function M.filter_running_runs(runs)
  if not runs or #runs == 0 then
    return {}
  end

  local running = {}
  for _, run in ipairs(runs) do
    if run.status == 'in_progress' or run.status == 'queued' then
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
