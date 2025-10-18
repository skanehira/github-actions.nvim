# Workflow History Feature Design

## Overview

This document describes the design for the workflow run history display feature. This feature allows users to view GitHub Actions workflow execution history, explore job and step details, and view logs for individual steps.

## User Requirements

1. Display workflow execution history in a buffer
2. Default to 10 most recent runs (with future pagination support)
3. Keyboard-driven UI for navigation and interaction
4. View logs for any step (both successful and failed) in a separate buffer

## UI/UX Design

### Main Buffer: Workflow Run History List

```
[GitHub Actions] .github/workflows/ci.yml - Run History
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ #123 main: Add new feature                    2h ago    3m 24s
✗ #122 fix/bug: Fix critical issue              5h ago    1m 45s
✓ #121 main: Update dependencies                1d ago    4m 12s
⊙ #120 feat/api: Implement new API    (running) 2d ago    1m 30s
⊘ #119 test: Add tests                (cancelled) 2d ago  45s
...

Press <CR> to expand, q to close, r to refresh
```

### Expanded View: Jobs and Steps

```
[GitHub Actions] .github/workflows/ci.yml - Run History
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ #123 main: Add new feature                    2h ago    3m 24s
✗ #122 fix/bug: Fix critical issue              5h ago    1m 45s
  Job: build
    ├─ ✓ Setup job                               3s
    ├─ ✓ Checkout code                           8s
    ├─ ✗ Run tests                               45s  ← Press <CR> to view logs
    └─ ⊘ Deploy                                  (skipped)
  Job: lint
    ├─ ✓ Setup job                               2s
    └─ ✓ Run linter                              12s
✓ #121 main: Update dependencies                1d ago    4m 12s
...

Press <CR> to expand/view logs, <BS> to collapse, q to close, r to refresh
```

### Log Buffer: Step Logs

```
[GitHub Actions] Logs: build / Run tests (#122)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2025-10-18T10:23:45.123Z ##[group]Run npm test
2025-10-18T10:23:45.234Z npm test
2025-10-18T10:23:46.345Z
2025-10-18T10:23:46.456Z > test
2025-10-18T10:23:46.567Z > jest
2025-10-18T10:23:47.678Z
2025-10-18T10:23:48.789Z FAIL spec/example_spec.js
2025-10-18T10:23:48.890Z   ● Test suite failed to run
2025-10-18T10:23:48.991Z
2025-10-18T10:23:49.012Z     Cannot find module './missing-file'
...

Press q to close
```

## Key Bindings

| Key | Action | Context |
|-----|--------|---------|
| `<CR>` | Expand run / View step logs | History buffer |
| `<BS>` / `h` | Collapse run | History buffer (when expanded) |
| `r` | Refresh history | History buffer |
| `q` | Close buffer | All buffers |
| `j` / `k` | Cursor movement | All buffers |

## Status Icons

```lua
{
  success = "✓",      -- Completed successfully
  failure = "✗",      -- Failed
  in_progress = "⊙",  -- Currently running
  cancelled = "⊘",    -- Cancelled by user
  skipped = "⊘",      -- Skipped (conditional)
  queued = "○",       -- Waiting to start
}
```

## User Flow

1. **Trigger**: User opens a workflow file and runs `:GhActionsHistory` (or custom keymap)
2. **Fetch**: Plugin retrieves the 10 most recent workflow runs via `gh` CLI
3. **Display**: New buffer shows run list with status, branch, title, time, and duration
4. **Expand**: User presses `<CR>` on a run to expand jobs and steps inline
5. **View Logs**: User presses `<CR>` on a step to open logs in a new buffer
6. **Refresh**: User presses `r` to fetch updated run list

## GitHub CLI Commands

### 1. Fetch Workflow Run List

```bash
gh run list \
  --workflow=ci.yml \
  --limit=10 \
  --json databaseId,displayTitle,headBranch,conclusion,status,createdAt,updatedAt
```

### 2. Fetch Jobs and Steps for a Run

```bash
gh run view <run-id> --json jobs
```

Response structure:
```json
{
  "jobs": [
    {
      "databaseId": 123456,
      "name": "build",
      "conclusion": "failure",
      "status": "completed",
      "steps": [
        {
          "name": "Setup job",
          "conclusion": "success",
          "status": "completed",
          "number": 1
        },
        {
          "name": "Run tests",
          "conclusion": "failure",
          "status": "completed",
          "number": 3
        }
      ]
    }
  ]
}
```

### 3. Fetch Step Logs

```bash
gh run view <run-id> --log --job=<job-id>
```

Or via API:
```bash
gh api /repos/{owner}/{repo}/actions/jobs/{job-id}/logs
```

## Architecture

### Module Structure

```
lua/github-actions/
├── init.lua                    # Add show_history() to setup
├── github.lua                  # Extend with new API methods
├── history/                    # New: History display feature
│   ├── init.lua               # Entry point: show_history()
│   ├── fetcher.lua            # GitHub API calls for runs/jobs/logs
│   ├── ui/
│   │   ├── runs_buffer.lua    # Manage history list buffer
│   │   ├── logs_buffer.lua    # Manage log display buffer
│   │   └── formatter.lua      # Format display strings
│   └── types.lua              # Type definitions: Run, Job, Step
├── workflow/
│   └── detector.lua           # New: Detect workflow file and extract name
└── lib/
    └── time.lua               # New: Time formatting utilities
```

### Module Responsibilities

#### `history/init.lua`
- Export `show_history(bufnr)` function
- Orchestrate: workflow detection → data fetch → UI display
- Handle errors and user notifications

#### `history/fetcher.lua`
- `fetch_runs(workflow_name, opts)`: Get run history
- `fetch_jobs(run_id)`: Get jobs and steps for a run
- `fetch_logs(job_id)`: Get logs for a specific job
- All async, callback-based (following existing pattern with `vim.system`)

#### `history/ui/runs_buffer.lua`
- Create and update history list buffer
- Manage expand/collapse state
- Set up keymaps
- Handle cursor positioning and line tracking

#### `history/ui/logs_buffer.lua`
- Create and display log buffer
- Set up syntax highlighting
- Configure buffer options (readonly, etc.)

#### `history/ui/formatter.lua`
- Generate display strings for runs, jobs, steps
- Format relative time ("2h ago", "1d ago")
- Select appropriate status icons
- Format duration ("3m 24s")

#### `workflow/detector.lua`
- Check if current buffer is a workflow file
- Extract workflow filename from buffer path
- Get repository information (owner, repo)

#### `lib/time.lua`
- `format_relative(iso_timestamp)`: "2h ago", "3d ago"
- `format_duration(seconds)`: "3m 24s", "1h 12m 34s"
- Parse ISO 8601 timestamps

## Data Types

### Run

```lua
---@class Run
---@field id number Workflow run ID
---@field display_title string Run title/commit message
---@field head_branch string Branch name
---@field conclusion string|nil "success"|"failure"|"cancelled"|nil
---@field status string "completed"|"in_progress"|"queued"
---@field created_at string ISO 8601 timestamp
---@field updated_at string ISO 8601 timestamp
---@field jobs Job[]|nil Jobs list (only when expanded)
---@field expanded boolean Whether run is currently expanded
```

### Job

```lua
---@class Job
---@field id number Job ID
---@field name string Job name
---@field conclusion string|nil "success"|"failure"|"skipped"|nil
---@field status string "completed"|"in_progress"|"queued"
---@field steps Step[] List of steps in this job
```

### Step

```lua
---@class Step
---@field name string Step name
---@field conclusion string|nil "success"|"failure"|"skipped"|nil
---@field status string "completed"|"in_progress"|"queued"
---@field number number Step number
---@field started_at string|nil Start timestamp
---@field completed_at string|nil Completion timestamp
```

## Data Flow

```
User triggers :GhActionsHistory
         ↓
workflow/detector.lua → Extract workflow filename
         ↓
history/fetcher.lua → fetch_runs() via gh CLI
         ↓
history/ui/formatter.lua → Format run list
         ↓
history/ui/runs_buffer.lua → Display buffer with keymaps
         ↓
User presses <CR> on a run
         ↓
history/fetcher.lua → fetch_jobs(run_id)
         ↓
history/ui/formatter.lua → Format jobs/steps
         ↓
history/ui/runs_buffer.lua → Update buffer (inline expansion)
         ↓
User presses <CR> on a step
         ↓
history/fetcher.lua → fetch_logs(job_id)
         ↓
history/ui/logs_buffer.lua → Display logs in new buffer
```

## Future Enhancements

### Pagination
- Add support for fetching more than 10 runs
- Implement "load more" functionality (press a key to fetch next page)
- Cache fetched runs to avoid refetching

### Filtering
- Filter by branch name
- Filter by status (success, failure, in_progress)
- Filter by conclusion
- Filter by date range

### Caching
- Extend existing `cache.lua` to cache run/job information
- Cache TTL configuration
- Smart cache invalidation on refresh

### Additional Features
- Re-run failed workflows from the UI
- Cancel running workflows
- View workflow file diff for each run
- Jump to workflow file location
- View run artifacts and download them

## Testing Strategy

Following the existing test structure:

```
spec/
├── history/
│   ├── fetcher_spec.lua       # Test API calls with fixtures
│   ├── ui/
│   │   ├── formatter_spec.lua # Test display string formatting
│   │   └── runs_buffer_spec.lua # Test buffer creation/updates
│   └── detector_spec.lua      # Test workflow file detection
├── lib/
│   └── time_spec.lua          # Test time formatting utilities
└── fixtures/
    └── history/
        ├── runs_list.json     # Sample gh run list response
        ├── run_jobs.json      # Sample gh run view response
        └── job_logs.txt       # Sample log output
```

## Implementation Phases

### Phase 1: Basic Run List Display
- Implement workflow detection
- Implement run list fetching
- Create basic buffer display
- Add basic keymaps (q to close)

### Phase 2: Expand/Collapse Jobs
- Implement job fetching
- Add expand/collapse functionality
- Update buffer rendering for jobs/steps

### Phase 3: Log Viewing
- Implement log fetching
- Create log buffer display
- Add navigation between buffers

### Phase 4: Polish
- Add refresh functionality
- Improve error handling
- Add loading indicators
- Optimize performance

### Phase 5: Future Enhancements
- Pagination support
- Filtering capabilities
- Caching improvements
- Additional features (re-run, cancel, etc.)
