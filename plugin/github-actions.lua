-- Global commands for github-actions plugin
-- This file is loaded on Neovim startup

local github_actions = require('github-actions')

local valid_modes = { tab = true, vsplit = true, split = true, current = true, float = true }
local mode_completions = vim.tbl_keys(valid_modes)

local function parse_open_mode_arg(args_str)
  if args_str and args_str ~= '' and valid_modes[args_str] then
    return args_str
  end
  return nil
end

-- Create global commands that are always available
vim.api.nvim_create_user_command('GithubActionsDispatch', function()
  github_actions.dispatch_workflow()
end, {
  desc = 'Dispatch a GitHub Actions workflow',
})

vim.api.nvim_create_user_command('GithubActionsHistory', function(opts)
  local args = {}
  local mode = parse_open_mode_arg(opts.args)
  if mode then
    args = { buffer = { history = { open_mode = mode } } }
  end
  github_actions.show_history(args)
end, {
  desc = 'Show workflow run history',
  nargs = '?',
  complete = function()
    return mode_completions
  end,
})

vim.api.nvim_create_user_command('GithubActionsWatch', function(opts)
  local args = {}
  local mode = parse_open_mode_arg(opts.args)
  if mode then
    args = { open_mode = mode }
  end
  github_actions.watch_workflow(args)
end, {
  desc = 'Watch running workflow execution',
  nargs = '?',
  complete = function()
    return mode_completions
  end,
})

vim.api.nvim_create_user_command('GithubActionsHistoryByPR', function(opts)
  local args = { pr_mode = true }
  local mode = parse_open_mode_arg(opts.args)
  if mode then
    args.buffer = { history = { open_mode = mode } }
  end
  github_actions.show_history(args)
end, {
  desc = 'Show workflow run history filtered by branch/PR',
  nargs = '?',
  complete = function()
    return mode_completions
  end,
})
