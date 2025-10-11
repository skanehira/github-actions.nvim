---@class Highlights
local M = {}

-- Define highlight groups if they don't exist
local highlights = {
  -- Version text highlights
  GitHubActionsVersionLatest = { fg = '#10d981', default = true }, -- Green
  GitHubActionsVersionOutdated = { fg = '#a855f7', default = true }, -- Purple

  -- Icon highlights
  GitHubActionsIconLatest = { fg = '#10d981', default = true }, -- Green
  GitHubActionsIconOutdated = { fg = '#a855f7', default = true }, -- Purple
}

---Setup default highlight groups for the plugin
function M.setup()
  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

return M
