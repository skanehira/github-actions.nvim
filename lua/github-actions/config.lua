---@class VirtualTextIcons
---@field outdated? string Icon for outdated versions (default: " ")
---@field latest? string Icon for latest versions (default: " ")
---@field error? string Icon for errors (default: " ")

---@class VirtualTextOptions
---@field enabled? boolean Enable version checking (default: true)
---@field icons? VirtualTextIcons Icons for version status
---@field highlight_latest? string Highlight for latest (default: "GitHubActionsVersionLatest")
---@field highlight_outdated? string Highlight for outdated (default: "GitHubActionsVersionOutdated")
---@field highlight_error? string Highlight for errors (default: "GitHubActionsVersionError")
---@field highlight_icon_latest? string Highlight for latest icon (default: "GitHubActionsIconLatest")
---@field highlight_icon_outdated? string Highlight for outdated icon (default: "GitHubActionsIconOutdated")
---@field highlight_icon_error? string Highlight for error icon (default: "GitHubActionsIconError")

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
---@field job_name? string Highlight group for job name
---@field step_name? string Highlight group for step name
---@field tree_prefix? string Highlight group for tree prefixes (├─, └─)

---@class HistoryListKeymaps
---@field close? string Key to close the buffer (default: 'q')
---@field expand? string Key to expand/collapse run or view logs (default: '<CR>')
---@field collapse? string Key to collapse expanded run (default: '<BS>')
---@field refresh? string Key to refresh history (default: 'r')
---@field rerun? string Key to rerun workflow (default: 'R')
---@field dispatch? string Key to dispatch workflow (default: 'd')
---@field watch? string Key to watch running workflow (default: 'w')
---@field cancel? string Key to cancel running workflow (default: 'C')
---@field open_browser? string Key to open run in browser (default: '<C-o>')

---@class HistoryLogsKeymaps
---@field close? string Key to close the buffer (default: 'q')

---@class HistoryKeymaps
---@field list? HistoryListKeymaps Keymaps for the workflow run list buffer
---@field logs? HistoryLogsKeymaps Keymaps for the logs buffer

---@class HistoryBufferOptions
---@field open_mode? string How to open buffers: "tab", "vsplit", "split", or "current" (default: "tab")
---@field buflisted? boolean Whether buffers should be listed in buffer list (default: true)

---@class HistoryOptions
---@field highlight_colors? HistoryHighlightOptions Highlight color options for workflow history display (global setup)
---@field highlights? HistoryHighlights Highlight group names for workflow history display (per-buffer)
---@field icons? HistoryIcons Icon options for workflow history display
---@field keymaps? HistoryKeymaps Keymap options for history buffers
---@field logs_fold_by_default? boolean Whether to fold log groups by default (default: true)
---@field buffer? HistoryBufferOptions Buffer display options

---@class GithubActionsConfig
---@field actions? VirtualTextOptions Display options for GitHub Actions version checking
---@field history? HistoryOptions Options for workflow history display

---@class Config
local M = {}

-- Default configuration
local defaults = {
  actions = {
    enabled = true,
    icons = {
      outdated = '',
      latest = '',
      error = '',
    },
    highlight_latest = 'GitHubActionsVersionLatest',
    highlight_outdated = 'GitHubActionsVersionOutdated',
    highlight_error = 'GitHubActionsVersionError',
    highlight_icon_latest = 'GitHubActionsIconLatest',
    highlight_icon_outdated = 'GitHubActionsIconOutdated',
    highlight_icon_error = 'GitHubActionsIconError',
  },
  history = {
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
      job_name = 'GitHubActionsHistoryJobName',
      step_name = 'GitHubActionsHistoryStepName',
      tree_prefix = 'GitHubActionsHistoryTreePrefix',
    },
    keymaps = {
      list = {
        close = 'q',
        expand = 'l',
        collapse = 'h',
        refresh = 'r',
        rerun = 'R',
        dispatch = 'd',
        watch = 'w',
        cancel = 'C',
        open_browser = '<C-o>',
      },
      logs = {
        close = 'q',
      },
    },
    logs_fold_by_default = true,
    buffer = {
      open_mode = 'tab',
      buflisted = true,
    },
  },
}

---Get default configuration
---@return GithubActionsConfig defaults Default configuration
function M.get_defaults()
  return vim.deepcopy(defaults)
end

---Merge user options with default configuration
---@param user_opts? GithubActionsConfig User configuration
---@return GithubActionsConfig merged_config Merged configuration
function M.merge_with_defaults(user_opts)
  if not user_opts then
    return M.get_defaults()
  end

  return vim.tbl_deep_extend('force', M.get_defaults(), user_opts)
end

---Merge custom icons with default icons
---@param icons table Default icons table
---@param custom_icons? HistoryIcons Custom icon configuration
---@return table merged_icons Merged icon configuration
function M.merge_icons(icons, custom_icons)
  if not custom_icons then
    return icons
  end

  local merged = vim.deepcopy(icons)
  for key, value in pairs(custom_icons) do
    if value ~= nil then
      merged[key] = value
    end
  end
  return merged
end

---Merge custom highlights with default highlights
---@param highlights table Default highlights table
---@param custom_highlights? HistoryHighlights Custom highlight configuration
---@return table merged_highlights Merged highlight configuration
function M.merge_highlights(highlights, custom_highlights)
  if not custom_highlights then
    return highlights
  end

  local merged = vim.deepcopy(highlights)
  for key, value in pairs(custom_highlights) do
    if value ~= nil then
      merged[key] = value
    end
  end
  return merged
end

return M
