# github-actions.nvim

A Neovim plugin for managing GitHub Actions workflows directly from Neovim.

<img width="923" height="534" alt="image" src="https://github.com/user-attachments/assets/47128a5b-f0d7-4f67-a226-238aa7e876a2" />

## Features

- 📦 Check GitHub Actions versions automatically
- 🚀 Dispatch workflows with `workflow_dispatch` trigger

## Requirements

- Neovim 0.9+
- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with YAML parser

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'skanehira/github-actions.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
  },
  opts = {},
}
```

## How It Works

The plugin automatically activates when you open:
- `.github/workflows/*.yml` or `*.yaml` (workflow files)
- `.github/actions/*/action.yml` or `*.yaml` (composite actions)

Version information is displayed inline at the end of each line using GitHub Actions:

```yaml
- uses: actions/checkout@v4   v5.0.0 (latest)
- uses: actions/setup-node@v3   v4.1.0 (outdated)
```

## Configuration

### Default Configuration

The plugin works out of the box with sensible defaults. You can customize it:

```lua
require('github-actions').setup({
  actions = {
    icons = {
      outdated = '',  -- Icon for outdated versions (default)
      latest = '',    -- Icon for latest versions (default)
      error = '',     -- Icon for error (default)
    },
    highlight_latest = 'GitHubActionsVersionLatest',      -- Highlight for latest versions
    highlight_outdated = 'GitHubActionsVersionOutdated',  -- Highlight for outdated versions
    highlight_error = 'GitHubActionsVersionError',        -- Highlight for error
    highlight_icon_latest = 'GitHubActionsIconLatest',    -- Highlight for latest icon
    highlight_icon_outdated = 'GitHubActionsIconOutdated', -- Highlight for outdated icon
    highlight_icon_error = 'GitHubActionsIconError',      -- Highlight for error icon
  },
})
```

## Commands

- `:GithubActionsDispatch` - Dispatch the current workflow (only available in workflow files with `workflow_dispatch` trigger)

## Keymaps

You can set up keymaps to call the plugin's functions directly:

```lua
{
  'skanehira/github-actions.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
  },
  keys = {
    {
      '<leader>gd',
      function()
        require('github-actions').dispatch_workflow()
      end,
      desc = 'Dispatch workflow',
    },
  },
  opts = {},
}
```
