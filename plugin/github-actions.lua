-- Global commands for github-actions plugin
-- This file is loaded on Neovim startup

-- Helper function to safely load the plugin
local function load_plugin()
  local ok, github_actions = pcall(require, 'github-actions')
  if not ok then
    vim.schedule(function()
      vim.notify('[GitHub Actions] Plugin not found', vim.log.levels.ERROR)
    end)
    return nil
  end
  return github_actions
end

-- Create global commands that are always available
vim.api.nvim_create_user_command('GithubActionsDispatch', function()
  local github_actions = load_plugin()
  if not github_actions then
    return
  end
  github_actions.dispatch_workflow()
end, {
  desc = 'Dispatch a GitHub Actions workflow using gh CLI',
})

vim.api.nvim_create_user_command('GithubActionsHistory', function()
  local github_actions = load_plugin()
  if not github_actions then
    return
  end
  github_actions.show_history()
end, {
  desc = 'Show workflow run history',
})
