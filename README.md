# github-actions.nvim

A Neovim plugin for managing GitHub Actions workflows directly from Neovim.

https://github.com/user-attachments/assets/c4566feb-c9c3-4a58-93d0-e6902c447a03

## Features

- 📦 Check GitHub Actions versions automatically
- 🚀 Dispatch workflows with `workflow_dispatch` trigger
- 📊 View workflow run history with status, duration, and timestamps
- 👁️ Watch running workflow executions in real-time
- ❌ Cancel running or queued workflow executions

## Requirements

- Neovim 0.9+
- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with YAML parser
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for enhanced workflow selection with multi-select and preview)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'skanehira/github-actions.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-telescope/telescope.nvim',  -- Optional: for enhanced workflow selection
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
- uses: actions/checkout@v5      v5.0.0
- uses: actions/setup-node@v3    v4.0.0
```

## Configuration

### Default Configuration

The plugin works out of the box with sensible defaults. You can customize it:

```lua
require('github-actions').setup({
  actions = {
    icons = {
      outdated = '',  -- Icon for outdated versions (default)
      latest = '',    -- Icon for latest versions (default)
      error = '',     -- Icon for error (default)
    },
    highlight_latest = 'GitHubActionsVersionLatest',      -- Highlight for latest versions
    highlight_outdated = 'GitHubActionsVersionOutdated',  -- Highlight for outdated versions
    highlight_error = 'GitHubActionsVersionError',        -- Highlight for error
    highlight_icon_latest = 'GitHubActionsIconLatest',    -- Highlight for latest icon
    highlight_icon_outdated = 'GitHubActionsIconOutdated', -- Highlight for outdated icon
    highlight_icon_error = 'GitHubActionsIconError',      -- Highlight for error icon
  },
  history = {
    icons = {
      success = '✓',      -- Icon for successful runs (default)
      failure = '✗',      -- Icon for failed runs (default)
      cancelled = '⊘',    -- Icon for cancelled runs (default)
      skipped = '⊘',      -- Icon for skipped runs (default)
      in_progress = '⊙',  -- Icon for in-progress runs (default)
      queued = '○',       -- Icon for queued runs (default)
      waiting = '○',      -- Icon for waiting runs (default)
      unknown = '?',      -- Icon for unknown status runs (default)
    },
    highlights = {
      success = 'GitHubActionsHistorySuccess',      -- Highlight for successful runs
      failure = 'GitHubActionsHistoryFailure',      -- Highlight for failed runs
      cancelled = 'GitHubActionsHistoryCancelled',  -- Highlight for cancelled runs
      running = 'GitHubActionsHistoryRunning',      -- Highlight for running runs
      queued = 'GitHubActionsHistoryQueued',        -- Highlight for queued runs
      run_id = 'GitHubActionsHistoryRunId',         -- Highlight for run ID
      branch = 'GitHubActionsHistoryBranch',        -- Highlight for branch name
      time = 'GitHubActionsHistoryTime',            -- Highlight for time information
      header = 'GitHubActionsHistoryHeader',        -- Highlight for header
      separator = 'GitHubActionsHistorySeparator',  -- Highlight for separator
    },
    -- Optional: customize highlight colors globally
    highlight_colors = {
      success = { fg = '#10b981', bold = true },     -- Highlight for successful runs
      failure = { fg = '#ef4444', bold = true },     -- Highlight for failed runs
      cancelled = { fg = '#6b7280', bold = true },   -- Highlight for cancelled runs
      running = { fg = '#f59e0b', bold = true },     -- Highlight for running runs
      queued = { fg = '#8b5cf6', bold = true },      -- Highlight for queued runs
    },
    -- Optional: customize keymaps for history buffers
    keymaps = {
      list = {                -- Workflow run list buffer
        close = 'q',          -- Close the buffer
        expand = 'l',         -- Expand/collapse run or view logs
        collapse = 'h',       -- Collapse expanded run
        refresh = 'r',        -- Refresh history
        rerun = 'R',          -- Rerun workflow
        dispatch = 'd',       -- Dispatch workflow
        watch = 'w',          -- Watch running workflow
        cancel = 'C',         -- Cancel running workflow
      },
      logs = {                -- Logs buffer
        close = 'q',          -- Close the buffer
      },
    },
  },
})
```

## Commands

- `:GithubActionsDispatch` - Dispatch the current workflow (only available in workflow files with `workflow_dispatch` trigger)
- `:GithubActionsHistory` - Show workflow run history for the current workflow file
- `:GithubActionsWatch` - Watch running workflow executions in real-time

### Workflow Selection

When running these commands outside of a workflow file, a picker will appear to select workflow files:

**With telescope.nvim (enhanced mode):**
- Use `<Tab>` to select multiple workflow files (history command only)
- Preview window shows the content of the selected workflow file
- Use `<C-u>` and `<C-d>` to scroll the preview window up and down
- Press `<CR>` to confirm selection
- Multiple selected workflows will open in separate tabs

**Without telescope.nvim (fallback mode):**
- Use `vim.ui.select` for single file selection
- No preview or multi-select support

### Workflow Watch Usage

The `:GithubActionsWatch` command allows you to monitor running workflow executions in real-time:

1. Run `:GithubActionsWatch` to open the workflow picker
2. Select a workflow file
3. The plugin will:
   - Fetch all workflow runs for the selected workflow
   - Filter to show only running workflows (status: `in_progress` or `queued`)
   - If no running workflows: Display an info message
   - If exactly one running workflow: Launch `gh run watch` directly in a new tab
   - If multiple running workflows: Show a picker to select which one to watch
4. The watch terminal opens in a new tab with `gh run watch <run-id>`
5. Exit the terminal with `Ctrl-C` or close the tab when done

**Run Picker Format**: `[icon] branch-name (#run-id)`
- Icon shows the run status (⊙ for in_progress, ○ for queued)
- Branch name indicates which branch triggered the workflow
- Run ID is the GitHub workflow run identifier

### Workflow History Usage

#### Run History Buffer

1. Press `l` on a workflow run to expand/collapse jobs and steps
2. Press `l` on a job to view its logs in a new buffer
3. Press `h` to collapse an expanded run
4. Press `r` to refresh the workflow run history
5. Press `R` to rerun the workflow at cursor
6. Press `d` to dispatch the current workflow (with inputs and branch selection)
7. Press `w` to watch a running workflow (only for in_progress or queued runs)
   - Opens a terminal running `gh run watch <run-id>`
   - Returns focus to history buffer in normal mode
   - Auto-refreshes history when watch completes
8. Press `C` to cancel a running workflow (only for in_progress or queued runs)
   - Auto-refreshes history when cancel completes
9. Press `q` to close the history buffer

#### Log Buffer

1. Press `q` to close the log buffer
2. Press `za` to toggle fold (open/close)
3. Press `zo` to open fold
4. Press `zc` to close fold

**Log Display**: Logs are automatically formatted to show only timestamps and content, removing redundant job and step name columns for better readability. Format: `[HH:MM:SS] log content`. Log groups are foldable for better navigation.

## Keymaps

You can set up keymaps to call the plugin's functions directly:

```lua
{
  'skanehira/github-actions.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    local actions = require('github-actions')
    vim.keymap.set('n', '<leader>gd', actions.dispatch_workflow, { desc = 'Dispatch workflow' })
    vim.keymap.set('n', '<leader>gh', actions.show_history, { desc = 'Show workflow history' })
    vim.keymap.set('n', '<leader>gw', actions.watch_workflow, { desc = 'Watch running workflow' })
    actions.setup({});
  end,
}
```
