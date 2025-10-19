local time = require('github-actions.lib.time')

local M = {}

-- Status icons
local ICONS = {
  success = '✓',
  failure = '✗',
  cancelled = '⊘',
  skipped = '⊘',
  in_progress = '⊙',
  queued = '○',
  waiting = '○',
  unknown = '?',
}

---Get status icon for a run
---@param status string Run status ("completed"|"in_progress"|"queued")
---@param conclusion string|nil Run conclusion ("success"|"failure"|"cancelled"|"skipped"|nil)
---@return string Icon
function M.get_status_icon(status, conclusion)
  if status == 'completed' and conclusion then
    return ICONS[conclusion] or ICONS.unknown
  end

  return ICONS[status] or ICONS.unknown
end

---Format a workflow run for display
---@param run table Run object with databaseId, displayTitle, headBranch, status, conclusion, createdAt, updatedAt
---@param current_time? number Current time (for testing)
---@return string Formatted run string
function M.format_run(run, current_time)
  local icon = M.get_status_icon(run.status, run.conclusion)
  local id = '#' .. run.databaseId
  local branch = run.headBranch .. ':'
  local title = run.displayTitle

  -- Calculate relative time
  local relative_time = time.format_relative(run.createdAt, current_time)

  -- Calculate duration
  local duration = ''
  if run.status == 'completed' then
    local created = time.parse_iso8601(run.createdAt)
    local updated = time.parse_iso8601(run.updatedAt)
    local duration_seconds = os.difftime(updated, created)
    duration = time.format_duration(math.floor(duration_seconds))
  elseif run.status == 'in_progress' then
    duration = '(running)'
  end

  -- Format: ✓ #12345 main: Add new feature  2h ago  3m 24s
  return string.format('%s %s %s %s  %s  %s', icon, id, branch, title, relative_time, duration)
end

return M
