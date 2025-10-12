# github-actions.nvim

A Neovim plugin that checks GitHub Actions versions and displays them inline using extmarks.

In the future, we plan to implement github actions execution and watch.

## Features

- 📦 Check GitHub Actions versions automatically

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
    },
    highlight_latest = 'GitHubActionsVersionLatest',      -- Highlight for latest versions
    highlight_outdated = 'GitHubActionsVersionOutdated',  -- Highlight for outdated versions
    highlight_icon_latest = 'GitHubActionsIconLatest',    -- Highlight for latest icon
    highlight_icon_outdated = 'GitHubActionsIconOutdated', -- Highlight for outdated icon
  },
})
```
