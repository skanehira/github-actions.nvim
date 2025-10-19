-- ftplugin for GitHub Actions workflow files
-- This file is loaded when opening YAML files

local bufnr = vim.api.nvim_get_current_buf()
local filepath = vim.api.nvim_buf_get_name(bufnr)

-- Only run for GitHub Actions workflow and composite action files
-- Patterns:
-- - .github/workflows/*.yml or *.yaml (workflow files)
-- - .github/actions/*/action.yml or action.yaml (composite actions)
local is_workflow = filepath:match('%.github/workflows/') ~= nil
local is_composite_action = filepath:match('%.github/actions/.*/action%.ya?ml$') ~= nil

if not (is_workflow or is_composite_action) then
  return
end

-- Check if plugin is loaded
local ok, github_actions = pcall(require, 'github-actions')
if not ok then
  vim.notify('github-actions plugin not found', vim.log.levels.ERROR)
  return
end

-- Auto-check on buffer enter
vim.defer_fn(function()
  if vim.api.nvim_buf_is_valid(bufnr) then
    github_actions.check_versions()
  end
end, 10)

-- Auto-check on text changes (debounced for performance)
vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  buffer = bufnr,
  callback = github_actions.check_versions,
  desc = 'Check GitHub Actions versions on text change (debounced)',
})

-- Add commands for workflow files
if is_workflow then
  vim.api.nvim_buf_create_user_command(bufnr, 'GithubActionsDispatch', function()
    github_actions.dispatch_workflow()
  end, {
    desc = 'Dispatch the current workflow using gh CLI',
  })

  vim.api.nvim_buf_create_user_command(bufnr, 'GithubActionsHistory', function()
    local history = require('github-actions.history.init')
    local config = github_actions.get_config()
    local icons = config.history and config.history.icons or nil
    local highlights = config.history and config.history.highlights or nil
    history.show_history(bufnr, icons, highlights)
  end, {
    desc = 'Show workflow run history for current buffer',
  })
end
