local time = require('github-actions.lib.time')

local M = {}

-- Default options
M.default_options = {
  icons = {
    success = '✓',
    failure = '✗',
    cancelled = '⊘',
    skipped = '⊘',
    in_progress = '⊙',
    queued = '○',
    waiting = '○',
    unknown = '?',
  },
  highlights = {
    success = 'GitHubActionsHistorySuccess',
    failure = 'GitHubActionsHistoryFailure',
    cancelled = 'GitHubActionsHistoryCancelled',
    running = 'GitHubActionsHistoryRunning',
    queued = 'GitHubActionsHistoryQueued',
    run_id = 'GitHubActionsHistoryRunId',
    branch = 'GitHubActionsHistoryBranch',
    time = 'GitHubActionsHistoryTime',
    header = 'GitHubActionsHistoryHeader',
    separator = 'GitHubActionsHistorySeparator',
  },
}

---@class HistoryIcons
---@field success? string Icon for successful runs
---@field failure? string Icon for failed runs
---@field cancelled? string Icon for cancelled runs
---@field skipped? string Icon for skipped runs
---@field in_progress? string Icon for in-progress runs
---@field queued? string Icon for queued runs
---@field waiting? string Icon for waiting runs
---@field unknown? string Icon for unknown status runs

---@class HistoryHighlights
---@field success? string Highlight group for successful runs
---@field failure? string Highlight group for failed runs
---@field cancelled? string Highlight group for cancelled runs
---@field running? string Highlight group for running runs
---@field queued? string Highlight group for queued runs
---@field run_id? string Highlight group for run ID
---@field branch? string Highlight group for branch name
---@field time? string Highlight group for time information
---@field header? string Highlight group for header
---@field separator? string Highlight group for separator

---Merge custom icons with default icons
---@param custom_icons? HistoryIcons Custom icon configuration
---@return table merged_icons Merged icon configuration
local function merge_icons(custom_icons)
  if not custom_icons then
    return M.default_options.icons
  end

  local merged = vim.deepcopy(M.default_options.icons)
  for key, value in pairs(custom_icons) do
    if value ~= nil then
      merged[key] = value
    end
  end
  return merged
end

---Merge custom highlights with default highlights
---@param custom_highlights? HistoryHighlights Custom highlight configuration
---@return table merged_highlights Merged highlight configuration
function M.merge_highlights(custom_highlights)
  if not custom_highlights then
    return M.default_options.highlights
  end

  local merged = vim.deepcopy(M.default_options.highlights)
  for key, value in pairs(custom_highlights) do
    if value ~= nil then
      merged[key] = value
    end
  end
  return merged
end

---Get status icon for a run
---@param status string Run status ("completed"|"in_progress"|"queued")
---@param conclusion string|nil Run conclusion ("success"|"failure"|"cancelled"|"skipped"|nil)
---@param custom_icons? HistoryIcons Custom icon configuration
---@return string Icon
function M.get_status_icon(status, conclusion, custom_icons)
  local icons = merge_icons(custom_icons)

  if status == 'completed' and conclusion then
    return icons[conclusion] or icons.unknown
  end

  return icons[status] or icons.unknown
end

---Format a workflow run for display
---@param run table Run object with databaseId, displayTitle, headBranch, status, conclusion, createdAt, updatedAt
---@param current_time? number Current time (for testing)
---@param custom_icons? HistoryIcons Custom icon configuration
---@return string Formatted run string
function M.format_run(run, current_time, custom_icons)
  local icon = M.get_status_icon(run.status, run.conclusion, custom_icons)
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
