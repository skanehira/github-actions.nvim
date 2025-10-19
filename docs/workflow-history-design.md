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

1. **Trigger**: User opens a workflow file and runs `:GithubActionsHistory` (or custom keymap)
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

**Note**: `databaseId` is the workflow run ID used in subsequent commands.

Example response:
```json
[
  {
    "conclusion": "success",
    "createdAt": "2025-10-18T04:09:29Z",
    "databaseId": 18610558363,
    "displayTitle": "chore: improve test (#2)",
    "headBranch": "main",
    "status": "completed",
    "updatedAt": "2025-10-18T04:10:30Z"
  }
]
```

### 2. Fetch Jobs and Steps for a Run

```bash
gh run view <run-id> --json jobs
```

**Note**: `<run-id>` is the `databaseId` from the run list response.

Example response:
```json
{
  "jobs": [
    {
      "completedAt": "2025-10-18T04:10:16Z",
      "conclusion": "success",
      "databaseId": 53068027249,
      "name": "test (ubuntu-latest, stable)",
      "startedAt": "2025-10-18T04:09:31Z",
      "status": "completed",
      "steps": [
        {
          "completedAt": "2025-10-18T04:09:36Z",
          "conclusion": "success",
          "name": "Set up job",
          "number": 1,
          "startedAt": "2025-10-18T04:09:32Z",
          "status": "completed"
        },
        {
          "completedAt": "2025-10-18T04:10:14Z",
          "conclusion": "success",
          "name": "Run tests",
          "number": 4,
          "startedAt": "2025-10-18T04:09:37Z",
          "status": "completed"
        }
      ],
      "url": "https://github.com/owner/repo/actions/runs/18610558363/job/53068027249"
    }
  ]
}
```

### 3. Fetch Step Logs

```bash
gh run view <run-id> --log --job=<job-id>
```

**Note**:
- `<run-id>` is the workflow run's `databaseId`
- `<job-id>` is the job's `databaseId` from the jobs response

Example output format:
```
test (ubuntu-latest, stable)	UNKNOWN STEP	2025-10-18T04:09:32.3975987Z Current runner version: '2.329.0'
test (ubuntu-latest, stable)	UNKNOWN STEP	2025-10-18T04:09:32.4000692Z ##[group]Runner Image Provisioner
test (ubuntu-latest, stable)	UNKNOWN STEP	2025-10-18T04:09:32.4001451Z Hosted Compute Agent
...
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
- Check if current buffer is a workflow file (`.github/workflows/*.yml`)
- Extract workflow name from YAML content (the `name:` field, not filename)
- Example: For a file with `name: CI`, return "CI" (not "ci.yaml")

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
---@field id number Job ID (databaseId from API)
---@field name string Job name
---@field conclusion string|nil "success"|"failure"|"skipped"|nil
---@field status string "completed"|"in_progress"|"queued"
---@field started_at string|nil ISO 8601 timestamp when job started
---@field completed_at string|nil ISO 8601 timestamp when job completed
---@field url string URL to the job on GitHub
---@field steps Step[] List of steps in this job
```

### Step

```lua
---@class Step
---@field name string Step name
---@field conclusion string|nil "success"|"failure"|"skipped"|nil
---@field status string "completed"|"in_progress"|"queued"
---@field number number Step number (used to identify step within job)
---@field started_at string|nil ISO 8601 timestamp when step started
---@field completed_at string|nil ISO 8601 timestamp when step completed
```

## Data Flow

```
User triggers :GithubActionsHistory
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
│   └── detector_spec.lua      # Test workflow file detection and name extraction
├── workflow/
│   └── detector_spec.lua      # Test is_workflow_file() and get_workflow_name()
├── lib/
│   └── time_spec.lua          # Test time formatting utilities
└── fixtures/
    └── history/
        ├── runs_list.json     # Sample gh run list response
        ├── run_jobs.json      # Sample gh run view response
        ├── job_logs.txt       # Sample log output
        └── workflow_files/    # Sample workflow YAML files for detector tests
            ├── ci.yml         # Example: name: CI
            ├── test.yml       # Example: name: Test
            └── no_name.yml    # Example: workflow without name field
```

## Implementation Phases

**IMPORTANT**: Follow TDD (Test-Driven Development) methodology for ALL phases:
1. **RED**: Write a failing test first
2. **GREEN**: Write minimal code to pass the test
3. **REFACTOR**: Improve code quality while keeping tests green

### Phase 1: Basic Run List Display

#### 1.1 Workflow Detection (TDD)
- **RED**: Write test for detecting `.github/workflows/*.yml` files
- **GREEN**: Implement `workflow/detector.lua` is_workflow_file() to pass the test
- **REFACTOR**: Extract reusable logic if needed
- **RED**: Write test for extracting workflow name from YAML content (`name: CI` → "CI")
- **GREEN**: Implement get_workflow_name() to parse YAML and extract name field
- **REFACTOR**: Handle edge cases (missing name field, comments, quoted values)

#### 1.2 Run List Fetching (TDD)
- **RED**: Write test for `fetch_runs()` with fixture data
- **GREEN**: Implement `history/fetcher.lua` fetch_runs() method
- **REFACTOR**: Extract gh CLI wrapper if needed
- **RED**: Write test for parsing run list JSON response
- **GREEN**: Implement JSON parsing and Run object creation
- **REFACTOR**: Optimize parsing logic

#### 1.3 Time Formatting (TDD)
- **RED**: Write test for `format_relative()` ("2h ago", "1d ago")
- **GREEN**: Implement `lib/time.lua` format_relative()
- **REFACTOR**: Handle edge cases
- **RED**: Write test for `format_duration()` ("3m 24s")
- **GREEN**: Implement format_duration()
- **REFACTOR**: Simplify duration logic

#### 1.4 Run List Formatting (TDD)
- **RED**: Write test for formatting single run display string
- **GREEN**: Implement `history/ui/formatter.lua` format_run()
- **REFACTOR**: Extract icon selection logic
- **RED**: Write test for status icon selection
- **GREEN**: Implement status-to-icon mapping
- **REFACTOR**: Clean up formatter

#### 1.5 Buffer Display (TDD)
- **RED**: Write test for creating history buffer
- **GREEN**: Implement `history/ui/runs_buffer.lua` create_buffer()
- **REFACTOR**: Extract buffer options setup
- **RED**: Write test for rendering run list in buffer
- **GREEN**: Implement render() method
- **REFACTOR**: Optimize rendering
- **RED**: Write test for 'q' keymap (close buffer)
- **GREEN**: Implement keymap setup
- **REFACTOR**: Extract keymap configuration

#### 1.6 Integration (TDD)
- **RED**: Write integration test for full workflow (detect → fetch → display)
- **GREEN**: Implement `history/init.lua` show_history()
- **REFACTOR**: Improve error handling and user feedback

### Phase 2: Expand/Collapse Jobs

#### 2.1 Job Fetching (TDD)
- **RED**: Write test for `fetch_jobs()` with fixture data
- **GREEN**: Implement fetch_jobs() in fetcher.lua
- **REFACTOR**: Reuse gh CLI wrapper
- **RED**: Write test for parsing jobs JSON response
- **GREEN**: Implement Job and Step object creation
- **REFACTOR**: Extract parsing logic

#### 2.2 Job/Step Formatting (TDD)
- **RED**: Write test for formatting job display string
- **GREEN**: Implement format_job() in formatter.lua
- **REFACTOR**: Handle indentation and tree structure
- **RED**: Write test for formatting step display string
- **GREEN**: Implement format_step()
- **REFACTOR**: Add duration formatting for steps

#### 2.3 Expand/Collapse Logic (TDD)
- **RED**: Write test for tracking expand state
- **GREEN**: Implement expand state management in runs_buffer.lua
- **REFACTOR**: Optimize state storage
- **RED**: Write test for <CR> keymap (expand run)
- **GREEN**: Implement expand functionality
- **REFACTOR**: Extract expand/collapse logic
- **RED**: Write test for <BS> keymap (collapse run)
- **GREEN**: Implement collapse functionality
- **REFACTOR**: Clean up keymap handlers

#### 2.4 Inline Rendering (TDD)
- **RED**: Write test for rendering expanded jobs/steps
- **GREEN**: Implement inline rendering in runs_buffer.lua
- **REFACTOR**: Optimize buffer update logic
- **RED**: Write test for cursor positioning after expand/collapse
- **GREEN**: Implement cursor management
- **REFACTOR**: Improve UX

### Phase 3: Log Viewing

#### 3.1 Log Fetching (TDD)
- **RED**: Write test for `fetch_logs()` with fixture data
- **GREEN**: Implement fetch_logs() in fetcher.lua
- **REFACTOR**: Handle async properly
- **RED**: Write test for log parsing/formatting
- **GREEN**: Implement log text processing
- **REFACTOR**: Handle special log formats (##[group], etc.)

#### 3.2 Log Buffer Display (TDD)
- **RED**: Write test for creating log buffer
- **GREEN**: Implement `history/ui/logs_buffer.lua` create_buffer()
- **REFACTOR**: Set up proper buffer options
- **RED**: Write test for rendering logs with syntax highlighting
- **GREEN**: Implement render() with highlights
- **REFACTOR**: Extract highlight configuration
- **RED**: Write test for 'q' keymap (close log buffer)
- **GREEN**: Implement close functionality
- **REFACTOR**: Clean up

#### 3.3 Navigation (TDD)
- **RED**: Write test for <CR> on step (open logs)
- **GREEN**: Implement step log navigation in runs_buffer.lua
- **REFACTOR**: Extract navigation logic
- **RED**: Write integration test for runs → logs flow
- **GREEN**: Ensure proper buffer switching
- **REFACTOR**: Improve navigation UX

### Phase 4: Polish

#### 4.1 Refresh Functionality (TDD)
- **RED**: Write test for 'r' keymap (refresh)
- **GREEN**: Implement refresh in runs_buffer.lua
- **REFACTOR**: Handle loading state
- **RED**: Write test for preserving cursor position on refresh
- **GREEN**: Implement cursor restoration
- **REFACTOR**: Optimize refresh

#### 4.2 Error Handling (TDD)
- **RED**: Write test for gh CLI errors
- **GREEN**: Implement error handling in fetcher.lua
- **REFACTOR**: Provide user-friendly error messages
- **RED**: Write test for network timeout
- **GREEN**: Implement timeout handling
- **REFACTOR**: Add retry logic if needed

#### 4.3 Loading Indicators (TDD)
- **RED**: Write test for showing loading state
- **GREEN**: Implement loading indicator in runs_buffer.lua
- **REFACTOR**: Use virtual text or status line
- **RED**: Write test for clearing loading state
- **GREEN**: Implement clear logic
- **REFACTOR**: Improve visual feedback

#### 4.4 Performance (TDD)
- **RED**: Write performance test for large run lists
- **GREEN**: Optimize rendering for many runs
- **REFACTOR**: Add lazy loading if needed
- **RED**: Write test for async operations
- **GREEN**: Ensure non-blocking UI
- **REFACTOR**: Optimize async flow

### Phase 5: Future Enhancements

Follow the same TDD approach for:
- Pagination support (test → implement → refactor)
- Filtering capabilities (test → implement → refactor)
- Caching improvements (test → implement → refactor)
- Additional features like re-run, cancel, etc. (test → implement → refactor)

**Remember**: NEVER write production code without a failing test first!
