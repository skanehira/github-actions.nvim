local git = require('github-actions.lib.git')
local select = require('github-actions.shared.select')

local M = {}

---Options for branch picker
---@class BranchPickerOptions
---@field prompt string Prompt text to display
---@field on_select function(selected: string) Callback with selected branch

---Select branch using telescope or vim.ui.select
---@param opts BranchPickerOptions Picker options
function M.select_branch(opts)
  -- Get remote branches
  local branches = git.get_remote_branches()
  if #branches == 0 then
    vim.notify('[GitHub Actions] No remote branches found', vim.log.levels.ERROR)
    return
  end

  -- Convert branches to SelectItem format
  local items = {}
  for _, branch in ipairs(branches) do
    table.insert(items, {
      value = branch,
      display = branch,
    })
  end

  select.select({
    prompt = opts.prompt,
    items = items,
    on_select = opts.on_select,
  })
end

return M
