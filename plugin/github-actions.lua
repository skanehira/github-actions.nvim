-- Global commands for github-actions plugin
-- This file is loaded on Neovim startup

local github_actions = require('github-actions')

local valid_modes = { tab = true, vsplit = true, split = true, current = true }

local function get_mode_completion()
  local modes = {}
  for mode in pairs(valid_modes) do
    table.insert(modes, mode)
  end
  return modes
end

-- Create global commands that are always available
vim.api.nvim_create_user_command('GithubActionsDispatch', function()
  github_actions.dispatch_workflow()
end, {
  desc = 'Dispatch a GitHub Actions workflow using gh CLI',
})

vim.api.nvim_create_user_command('GithubActionsHistory', function(opts)
  -- Parse arguments if provided
  local args = {}
  if opts.args and opts.args ~= '' then
    -- Support open_mode argument: e.g., :GithubActionsHistory tab, vsplit, split, current
    if valid_modes[opts.args] then
      args = { buffer = { open_mode = opts.args } }
    end
  end
  github_actions.show_history(args)
end, {
  desc = 'Show workflow run history',
  nargs = '?',
  complete = function()
    return get_mode_completion()
  end,
})

vim.api.nvim_create_user_command('GithubActionsWatch', function()
  github_actions.watch_workflow()
end, {
  desc = 'Watch running workflow execution using gh CLI',
})

vim.api.nvim_create_user_command('GithubActionsHistoryByPR', function(opts)
  -- Parse arguments if provided
  local args = { pr_mode = true }
  if opts.args and opts.args ~= '' then
    -- Support open_mode argument: e.g., :GithubActionsHistoryByPR tab, vsplit, split, current
    if valid_modes[opts.args] then
      args.buffer = { open_mode = opts.args }
    end
  end
  github_actions.show_history(args)
end, {
  desc = 'Show workflow run history filtered by branch/PR',
  nargs = '?',
  complete = function()
    return get_mode_completion()
  end,
})
