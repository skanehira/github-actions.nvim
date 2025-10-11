---@class GithubActionsConfig
---@field virtual_text? VirtualTextOptions Virtual text display options

---@class GithubActions
local M = {}

local checker = require('github-actions.checker')
local ui = require('github-actions.ui')

---Current configuration
---@type GithubActionsConfig
local config = {}

---Setup the plugin with user configuration
---@param opts? GithubActionsConfig User configuration
function M.setup(opts)
  -- Setup highlight groups
  ui.highlights.setup()

  -- Build default configuration (must be done here to get current default_options)
  local default_config = {
    virtual_text = vim.deepcopy(ui.version.default_options),
  }

  -- Merge user config with defaults
  config = vim.tbl_deep_extend('force', default_config, opts or {})
end

---Check and update version information for current buffer
function M.check_versions()
  local bufnr = vim.api.nvim_get_current_buf()
  checker.update_buffer(bufnr, config.virtual_text)
end

return M
