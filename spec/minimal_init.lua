-- Minimal init for busted tests
-- This file is loaded by each test via dofile()

-- Add the plugin to runtimepath
vim.opt.runtimepath:append('.')

-- Set up minimal configuration
vim.opt.swapfile = false
vim.opt.hidden = true

-- Setup nvim-treesitter for tests
local treesitter_path = './deps/nvim-treesitter'
if vim.fn.isdirectory(treesitter_path) == 1 then
  vim.opt.runtimepath:prepend(treesitter_path)

  -- Configure nvim-treesitter to install parsers to deps/parsers
  local cwd = vim.fn.getcwd()
  if not cwd then
    cwd = vim.fn.fnamemodify('.', ':p:h')
  end
  require('nvim-treesitter.configs').setup({
    parser_install_dir = cwd .. '/deps/parsers',
    ensure_installed = { 'yaml' },
    sync_install = true,
    ignore_install = {},
    auto_install = true,
    modules = {},
  })

  -- Add parser directory to runtimepath
  vim.opt.runtimepath:prepend('./deps/parsers')
end
