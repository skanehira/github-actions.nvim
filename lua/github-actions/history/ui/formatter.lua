local time = require('github-actions.lib.time')

local M = {}

---Get status icon for a run
---@param status string Run status ("completed"|"in_progress"|"queued")
---@param conclusion string|nil Run conclusion ("success"|"failure"|"cancelled"|"skipped"|nil)
---@param icons HistoryIcons Icon configuration (should be pre-merged with defaults)
---@return string Icon
function M.get_status_icon(status, conclusion, icons)
  if status == 'completed' and conclusion then
    return icons[conclusion] or icons.unknown or ''
  end

  return icons[status] or icons.unknown or ''
end

---Format a workflow run for display
---@param run table Run object with databaseId, displayTitle, headBranch, status, conclusion, createdAt, updatedAt
---@param current_time? number Current time (for testing)
---@param icons HistoryIcons Icon configuration (should be pre-merged with defaults)
---@return string Formatted run string
function M.format_run(run, current_time, icons)
  local icon = M.get_status_icon(run.status, run.conclusion, icons)
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

---Format a job for display
---@param job table Job object with name, status, conclusion, startedAt, completedAt
---@param icons HistoryIcons Icon configuration (should be pre-merged with defaults)
---@return string Formatted job string
function M.format_job(job, icons)
  local icon = M.get_status_icon(job.status, job.conclusion, icons)
  local name = 'Job: ' .. job.name

  -- Calculate duration
  local duration = ''
  if job.status == 'completed' and job.startedAt and job.completedAt then
    local started = time.parse_iso8601(job.startedAt)
    local completed = time.parse_iso8601(job.completedAt)
    local duration_seconds = os.difftime(completed, started)
    duration = time.format_duration(math.floor(duration_seconds))
  elseif job.status == 'in_progress' then
    duration = '(running)'
  end

  -- Format: Job: test (ubuntu-latest, stable)  ✓  3m 24s
  return string.format('  %s %s  %s', icon, name, duration)
end

---Format a step for display
---@param step table Step object with name, status, conclusion, startedAt, completedAt
---@param is_last boolean Whether this is the last step in the job
---@param icons HistoryIcons Icon configuration (should be pre-merged with defaults)
---@return string Formatted step string
function M.format_step(step, is_last, icons)
  local icon = M.get_status_icon(step.status, step.conclusion, icons)
  local prefix = is_last and '└─' or '├─'

  -- Calculate duration
  local duration = ''
  if step.status == 'completed' and step.conclusion ~= 'skipped' and step.startedAt and step.completedAt then
    local started = time.parse_iso8601(step.startedAt)
    local completed = time.parse_iso8601(step.completedAt)
    local duration_seconds = os.difftime(completed, started)
    duration = time.format_duration(math.floor(duration_seconds))
  elseif step.conclusion == 'skipped' then
    duration = '(skipped)'
  elseif step.status == 'in_progress' then
    duration = '(running)'
  end

  -- Format:     ├─ ✓ Run tests  45s
  return string.format('    %s %s %s  %s', prefix, icon, step.name, duration)
end

return M
