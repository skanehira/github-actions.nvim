# github-actions.nvim

A Neovim plugin for managing GitHub Actions workflows directly from Neovim.

https://github.com/user-attachments/assets/c4566feb-c9c3-4a58-93d0-e6902c447a03

## Features

- 📦 Check GitHub Actions versions automatically
- 🚀 Dispatch workflows with `workflow_dispatch` trigger
- 📊 View workflow run history with status, duration, and timestamps
- 🔍 View workflow history filtered by branch/PR
- 👁️ Watch running workflow executions in real-time
- 🔄 Rerun workflows (all jobs or failed jobs only)
- ❌ Cancel running or queued workflow executions
- 🔗 Open workflow/run/job URLs in browser

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
    enabled = true,     -- Enable version checking (default: true)
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
        open_browser = '<C-o>',  -- Open run/job URL in browser
      },
      logs = {                -- Logs buffer
        close = 'q',          -- Close the buffer
      },
    },
    -- Optional: configure how buffers are opened
    buffer = {
      history = {
        open_mode = 'tab',    -- How to open history buffer: 'tab', 'vsplit', 'split', or 'current' (default: 'tab')
        buflisted = true,     -- Whether buffer appears in buffer list (default: true)
        window_options = {    -- Window-local options to set (default: {wrap = true})
          wrap = true,        -- Enable line wrapping
          number = true,      -- Show line numbers
          cursorline = true,  -- Highlight current line
        },
      },
      logs = {
        open_mode = 'vsplit', -- How to open logs buffer: 'tab', 'vsplit', 'split', or 'current' (default: 'vsplit')
        buflisted = true,     -- Whether buffer appears in buffer list (default: true)
        window_options = {    -- Window-local options to set (default: {wrap = false})
          wrap = false,       -- Disable line wrapping (better for log files)
          number = false,     -- Hide line numbers
        },
      },
    },
  },
})
```

## Commands

- `:GithubActionsDispatch` - Dispatch the current workflow (only available in workflow files with `workflow_dispatch` trigger)
- `:GithubActionsHistory` - Show workflow run history for the current workflow file
- `:GithubActionsHistoryByPR` - Show workflow run history filtered by branch/PR
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

### Branch/PR History Usage

The `:GithubActionsHistoryByPR` command allows you to view workflow run history filtered by branch or PR:

1. Run `:GithubActionsHistoryByPR` to open the branch/PR picker
2. The picker shows all remote branches with associated PR numbers (format: `branch-name #PR-number`)
3. Current branch name is pre-filled in the search input for quick selection
4. Select a branch to view all workflow runs for that branch
5. The history buffer works the same as the standard workflow history

### Workflow History Usage

#### Run History Buffer

1. Press `l` on a workflow run to expand/collapse jobs and steps
2. Press `l` on a job to view its logs in a new buffer
3. Press `h` to collapse an expanded run
4. Press `r` to refresh the workflow run history
5. Press `R` to rerun the workflow at cursor
   - For failed runs: Shows a picker to choose "Rerun all jobs" or "Rerun failed jobs only"
   - For non-failed runs: Reruns all jobs directly
6. Press `d` to dispatch the current workflow (with inputs and branch selection)
7. Press `w` to watch a running workflow (only for in_progress or queued runs)
   - Opens a terminal running `gh run watch <run-id>`
   - Returns focus to history buffer in normal mode
   - Auto-refreshes history when watch completes
8. Press `C` to cancel a running workflow (only for in_progress or queued runs)
   - Auto-refreshes history when cancel completes
9. Press `<C-o>` to open the run or job URL in browser
   - On a run line: Opens the workflow run page on GitHub
   - On a job line: Opens the specific job page on GitHub
10. Press `q` to close the history buffer

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
    vim.keymap.set('n', '<leader>gp', function() actions.show_history({ pr_mode = true }) end, { desc = 'Show workflow history by branch/PR' })
    vim.keymap.set('n', '<leader>gw', actions.watch_workflow, { desc = 'Watch running workflow' })
    vim.keymap.set('n', '<leader>go', actions.open_workflow_url, { desc = 'Open workflow URL in browser' })
    actions.setup({});
  end,
}
```
