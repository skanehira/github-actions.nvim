---@class GithubActions
local M = {}

local versions = require('github-actions.versions')
local dispatch = require('github-actions.dispatch')
local history = require('github-actions.history')
local watch = require('github-actions.watch')
local highlights = require('github-actions.lib.highlights')
local cfg = require('github-actions.config')

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

  -- Merge user config with defaults
  config = cfg.merge_with_defaults(opts)
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
  dispatch.dispatch_workflow()
end

---Show workflow run history for the current buffer
function M.show_history()
  history.show_history(config.history)
end

---Watch running workflow execution
function M.watch_workflow()
  watch.watch_workflow(config.history)
end

return M
