---@class HistoryOptions
---@field highlight_colors? HistoryHighlightOptions Highlight color options for workflow history display (global setup)
---@field highlights? HistoryHighlights Highlight group names for workflow history display (per-buffer)
---@field icons? HistoryIcons Icon options for workflow history display
---@field logs_fold_by_default? boolean Whether to fold log groups by default (default: true)

---@class GithubActionsConfig
---@field actions? VirtualTextOptions Display options for GitHub Actions version checking
---@field history? HistoryOptions Options for workflow history display

---@class GithubActions
local M = {}

local versions = require('github-actions.versions')
local dispatch = require('github-actions.dispatch')
local history = require('github-actions.history')
local display = require('github-actions.versions.ui.display')
local highlights = require('github-actions.lib.highlights')
local formatter = require('github-actions.history.ui.formatter')

---Current configuration
---@type GithubActionsConfig
local config = {}

---Setup the plugin with user configuration
---@param opts? GithubActionsConfig User configuration
function M.setup(opts)
  opts = opts or {}

  -- Setup highlight groups with custom history highlight colors if provided
  local history_highlight_colors = opts.history and opts.history.highlight_colors or nil
  highlights.setup(history_highlight_colors)

  -- Build default configuration (must be done here to get current default_options)
  local default_config = {
    actions = vim.deepcopy(display.default_options),
    history = vim.deepcopy(formatter.default_options),
  }

  -- Merge user config with defaults
  config = vim.tbl_deep_extend('force', default_config, opts)
end

---Get current configuration
---@return GithubActionsConfig config Current configuration
function M.get_config()
  return config
end

---Check and update version information for current buffer
function M.check_versions()
  local bufnr = vim.api.nvim_get_current_buf()
  versions.check_versions(bufnr, config.actions)
end

---Dispatch the workflow in the current buffer
function M.dispatch_workflow()
  local bufnr = vim.api.nvim_get_current_buf()
  dispatch.dispatch_workflow(bufnr)
end

---Show workflow run history for the current buffer
function M.show_history()
  local bufnr = vim.api.nvim_get_current_buf()
  history.show_history(bufnr, config.history)
end

return M
