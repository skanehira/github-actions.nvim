-- Development configuration
-- Load this file to test the plugin during development
--
-- Usage:
--   nvim -u dev.lua .github/workflows/test.yml

-- Add current directory to runtimepath
vim.opt.runtimepath:append('.')

-- Disable swap files for cleaner testing
vim.opt.swapfile = false

-- Setup nvim-treesitter for YAML parsing
local treesitter_path = './deps/nvim-treesitter'
if vim.fn.isdirectory(treesitter_path) == 1 then
  vim.opt.runtimepath:prepend(treesitter_path)

  -- Configure nvim-treesitter to use deps/parsers
  require('nvim-treesitter.configs').setup({
    parser_install_dir = vim.fn.getcwd() .. '/deps/parsers',
    ensure_installed = { 'yaml' },
    sync_install = false,
    ignore_install = {},
    auto_install = false,
    modules = {},
  })

  -- Add parser directory to runtimepath
  vim.opt.runtimepath:prepend('./deps/parsers')
end

-- Setup the plugin (uses default options from virtual_text.lua)
require('github-actions').setup()

-- Or customize if needed:
-- require('github-actions').setup({
--   virtual_text = {
--     prefix = ' >> ',
--     icons = {
--       outdated = '⚠',
--       latest = '✓',
--     },
--   },
-- })

-- Set up keymaps
vim.keymap.set('n', '<leader>gc', function()
  require('github-actions').check_versions()
end, { desc = 'Check GitHub Actions versions' })

vim.keymap.set('n', '<leader>gC', function()
  local virtual_text = require('github-actions.ui.virtual_text')
  virtual_text.clear_virtual_text(vim.api.nvim_get_current_buf())
end, { desc = 'Clear version virtual text' })

-- Print helpful message
vim.defer_fn(function()
  print('GitHub Actions plugin loaded!')
  print('Keymaps:')
  print('  <leader>gc - Check versions (uses cache)')
  print('  <leader>gC - Clear virtual text')
  print('  <leader>gX - Clear version cache')
  print('')
  print('Auto-check: Versions are checked on buffer enter and save')
  print('Cache: First check fetches from API, subsequent checks use cache')
end, 100)
