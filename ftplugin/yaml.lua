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

-- Auto-check on text changes (debounced to coalesce rapid edits into a single check)
local DEBOUNCE_MS = 500
local debounce_timer = nil

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  buffer = bufnr,
  callback = function()
    if debounce_timer then
      debounce_timer:stop()
      debounce_timer:close()
      debounce_timer = nil
    end
    -- Capture our own timer in a local so the scheduled callback can identify
    -- itself: between `defer_fn` firing and the callback actually running, a
    -- new TextChanged may have stopped this timer and stored a NEW one in
    -- `debounce_timer`. Nulling the shared variable unconditionally would
    -- orphan the new timer and leak a spurious check_versions invocation.
    local self_timer
    self_timer = vim.defer_fn(function()
      if debounce_timer == self_timer then
        debounce_timer = nil
      end
      if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_current_buf() == bufnr then
        github_actions.check_versions()
      end
    end, DEBOUNCE_MS)
    debounce_timer = self_timer
  end,
  desc = 'Check GitHub Actions versions on text change (debounced)',
})

vim.api.nvim_create_autocmd('BufWipeout', {
  buffer = bufnr,
  callback = function()
    if debounce_timer then
      debounce_timer:stop()
      debounce_timer:close()
      debounce_timer = nil
    end
  end,
})
