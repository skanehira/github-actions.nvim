-- Global commands for github-actions plugin
-- This file is loaded on Neovim startup

local github_actions = require('github-actions')

-- Create global commands that are always available
vim.api.nvim_create_user_command('GithubActionsDispatch', function()
  github_actions.dispatch_workflow()
end, {
  desc = 'Dispatch a GitHub Actions workflow using gh CLI',
})

vim.api.nvim_create_user_command('GithubActionsHistory', function()
  github_actions.show_history()
end, {
  desc = 'Show workflow run history',
})

vim.api.nvim_create_user_command('GithubActionsWatch', function()
  github_actions.watch_workflow()
end, {
  desc = 'Watch running workflow execution using gh CLI',
})
