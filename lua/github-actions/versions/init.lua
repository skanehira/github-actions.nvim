---@class VersionsModule
local M = {}

local checker = require('github-actions.versions.checker')
local display = require('github-actions.versions.ui.display')

---Check versions and display results
---@param bufnr number Buffer number
---@param config table Display configuration options
function M.check_versions(bufnr, config)
  -- Skip if version checking is disabled
  if config.enabled == false then
    return
  end

  checker.check_versions(bufnr, function(version_infos, error)
    -- Error handling
    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    -- Display results
    display.show_versions(bufnr, version_infos, config)
  end)
end

return M
