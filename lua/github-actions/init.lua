---@class GithubActionsConfig
---@field actions? VirtualTextOptions Display options for GitHub Actions version checking

---@class GithubActions
local M = {}

local checker = require('github-actions.workflow.checker')
local display = require('github-actions.display')
local highlights = require('github-actions.lib.highlights')

---Current configuration
---@type GithubActionsConfig
local config = {}

---Setup the plugin with user configuration
---@param opts? GithubActionsConfig User configuration
function M.setup(opts)
  -- Setup highlight groups
  highlights.setup()

  -- Build default configuration (must be done here to get current default_options)
  local default_config = {
    actions = vim.deepcopy(display.default_options),
  }

  -- Merge user config with defaults
  config = vim.tbl_deep_extend('force', default_config, opts or {})
end

---Check and update version information for current buffer
function M.check_versions()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Business logic: check versions
  checker.check_versions(bufnr, function(version_infos, error)
    -- Error handling
    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    -- UI: display results
    display.show_versions(bufnr, version_infos, config.actions)
  end)
end

return M
