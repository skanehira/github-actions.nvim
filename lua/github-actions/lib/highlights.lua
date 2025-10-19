---@class HistoryHighlightOptions
---@field success? table Highlight options for successful runs
---@field failure? table Highlight options for failed runs
---@field cancelled? table Highlight options for cancelled runs
---@field running? table Highlight options for running runs
---@field queued? table Highlight options for queued runs
---@field run_id? table Highlight options for run ID
---@field branch? table Highlight options for branch name
---@field time? table Highlight options for time information
---@field header? table Highlight options for header
---@field separator? table Highlight options for separator
---@field job_name? table Highlight options for job name
---@field step_name? table Highlight options for step name
---@field tree_prefix? table Highlight options for tree prefixes (├─, └─)

---@class Highlights
local M = {}

-- Default highlight configurations
local default_highlights = {
  -- Version text highlights
  GitHubActionsVersionLatest = { fg = '#10d981', default = true }, -- Green
  GitHubActionsVersionOutdated = { fg = '#a855f7', default = true }, -- Purple
  GitHubActionsVersionError = { fg = '#ef4444', default = true }, -- Red

  -- Icon highlights
  GitHubActionsIconLatest = { fg = '#10d981', default = true }, -- Green
  GitHubActionsIconOutdated = { fg = '#a855f7', default = true }, -- Purple
  GitHubActionsIconError = { fg = '#ef4444', default = true }, -- Red

  -- History buffer highlights
  GitHubActionsHistorySuccess = { fg = '#10b981', bold = true, default = true }, -- Green
  GitHubActionsHistoryFailure = { fg = '#ef4444', bold = true, default = true }, -- Red
  GitHubActionsHistoryCancelled = { fg = '#6b7280', bold = true, default = true }, -- Gray
  GitHubActionsHistoryRunning = { fg = '#f59e0b', bold = true, default = true }, -- Orange
  GitHubActionsHistoryQueued = { fg = '#8b5cf6', bold = true, default = true }, -- Purple
  GitHubActionsHistoryRunId = { fg = '#3b82f6', default = true }, -- Blue
  GitHubActionsHistoryBranch = { fg = '#06b6d4', italic = true, default = true }, -- Cyan
  GitHubActionsHistoryTime = { fg = '#64748b', default = true }, -- Slate
  GitHubActionsHistoryHeader = { fg = '#94a3b8', bold = true, default = true }, -- Light slate
  GitHubActionsHistorySeparator = { fg = '#475569', default = true }, -- Dark slate
  GitHubActionsHistoryJobName = { fg = '#a78bfa', bold = true, default = true }, -- Light purple
  GitHubActionsHistoryStepName = { fg = '#93c5fd', default = true }, -- Light blue
  GitHubActionsHistoryTreePrefix = { fg = '#64748b', default = true }, -- Slate
}

---Apply custom history highlight options to default highlights
---@param custom_opts? HistoryHighlightOptions User-provided history highlight options
---@return table highlights Merged highlight configuration
local function merge_history_highlights(custom_opts)
  local highlights = vim.deepcopy(default_highlights)

  if not custom_opts then
    return highlights
  end

  -- Map user-friendly option keys to actual highlight group names
  local mapping = {
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
    job_name = 'GitHubActionsHistoryJobName',
    step_name = 'GitHubActionsHistoryStepName',
    tree_prefix = 'GitHubActionsHistoryTreePrefix',
  }

  for option_key, hl_group in pairs(mapping) do
    if custom_opts[option_key] then
      -- Merge custom options with default, preserving default=true
      highlights[hl_group] = vim.tbl_extend('force', highlights[hl_group], custom_opts[option_key])
    end
  end

  return highlights
end

---Setup highlight groups for the plugin
---@param opts? HistoryHighlightOptions User-provided history highlight options
function M.setup(opts)
  local highlights = merge_history_highlights(opts)

  for group, hl_opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, hl_opts)
  end
end

return M
