# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin written in Lua that provides comprehensive GitHub Actions workflow management:
- **Version Checking**: Automatically checks GitHub Actions versions and displays them inline using extmarks
- **Workflow Dispatch**: Trigger workflows with `workflow_dispatch` support
- **Run History**: Browse workflow run history with expandable jobs and steps
- **Live Watch**: Monitor running workflow executions in real-time
- **Rerun/Cancel**: Rerun workflows (all jobs or failed only) and cancel running workflows

The plugin automatically activates for `.github/workflows/*.yml` files and `.github/actions/*/action.yml` files, parsing them with treesitter and showing version information as virtual text at the end of each line.

## Development Commands

### Testing (Docker-based)
```bash
# Run all tests
make test

# Run a specific test file
make test-file FILE=spec/parser_spec.lua
```

### Code Quality
```bash
# Run linter (luacheck, Docker-based)
make lint

# Format code (stylua, requires local installation)
make format

# Check formatting without modifying files
make check
```

### Test Infrastructure
- Tests use busted framework with nlua, running inside Docker container
- `spec/minimal_init.lua` is loaded by each test via `dofile('spec/minimal_init.lua')`
- Test fixtures are in `spec/fixtures/`
- Helper modules are in `spec/helpers/`

## Architecture

### Core Components

**Entry Point (`lua/github-actions/init.lua`)**
- Exports `setup(opts)` for plugin configuration
- Exports `check_versions()` to trigger version checking
- Exports `dispatch_workflow()` to trigger workflow dispatch
- Exports `show_history()` to display workflow run history
- Exports `watch_workflow()` to watch running workflow executions
- Orchestrates the workflow: checker → display

**Workflow Processing (`lua/github-actions/workflow/`)**
- `parser.lua`: Uses treesitter YAML queries to extract GitHub Actions from buffer
  - Returns `Action[]` with owner, repo, version/hash, line, col
- `checker.lua`: Business logic for version checking
  - Coordinates parsing, GitHub API calls, and caching
  - Async callback-based architecture with `vim.system` for gh CLI calls

**GitHub Integration (`lua/github-actions/github.lua`)**
- Wraps `gh` CLI for GitHub API calls
- `fetch_latest_release()`: Primary method, falls back to `fetch_latest_tag()` if no release exists
- Uses `vim.system()` for async command execution
- Returns version info via callbacks

**Display Layer (`lua/github-actions/display.lua`)**
- Manages virtual text via extmarks in dedicated namespace
- `show_versions()`: High-level function that clears and displays version info
- Configurable icons and highlight groups
- Displays three states: latest (✓), outdated (⚠), error (✗)

**Watch Module (`lua/github-actions/watch/`)**
- `init.lua`: Entry point for watch functionality, orchestrates workflow selection to terminal launch
- `filter.lua`: Filters running workflows (status: `in_progress` or `queued`)
- `run_picker.lua`: Displays picker to select from multiple running workflows
- Launches `gh run watch` in new tab for real-time monitoring
- Reuses `shared/picker.lua` and `history/api.lua` for consistency

**History Module (`lua/github-actions/history/`)**
- `init.lua`: Entry point for history functionality
- `api.lua`: GitHub API calls for workflow runs
  - `fetch_runs()`: Fetches workflow run history
  - `fetch_jobs()`: Fetches jobs for a specific run
  - `fetch_logs()`: Fetches logs for a specific job
  - `rerun(run_id, callback, options)`: Reruns a workflow run using `gh run rerun`
    - Supports `options.failed_only` to rerun only failed jobs (`--failed` flag)
- `ui/runs_buffer.lua`: Manages the history buffer display
  - Keymaps are customizable via `config.history.keymaps.list`
  - Default: `l` expand/logs, `h` collapse, `r` refresh, `R` rerun, `d` dispatch, `w` watch, `q` close
  - Stores `workflow_filepath` for dispatch functionality
  - Rerun shows picker for failed runs to choose "all jobs" or "failed jobs only"
- `ui/logs_buffer.lua`: Manages the logs buffer display
  - Keymaps are customizable via `config.history.keymaps.logs`
  - Default: `q` close (fold keymaps use Vim standard)

**Dispatch Module (`lua/github-actions/dispatch/`)**
- `init.lua`: Entry point for workflow dispatch
  - Exports `dispatch_workflow()`: Interactive workflow dispatch with file picker
  - Exports `dispatch_workflow_for_file(filepath)`: Dispatch a specific workflow file (used by history buffer)
- `parser.lua`: Parses `workflow_dispatch` configuration from workflow files
- `input_collector.lua`: Collects input parameters from user

**PR Module (`lua/github-actions/pr/`)**
- `init.lua`: Entry point for PR/branch filtered history
  - Exports `show_pr_history(history_config)`: Shows branch/PR picker then displays filtered workflow history
- `api.lua`: PR and branch data fetching
  - `get_current_branch()`: Gets current git branch name
  - `fetch_remote_branches(callback)`: Fetches remote branches via `git branch -r`
  - `fetch_open_prs(callback)`: Fetches open PRs via `gh pr list`
  - `fetch_branches_with_prs(callback)`: Combines branches with PR info

**Shared Modules (`lua/github-actions/shared/`)**
- `select.lua`: Generic selection UI utility
  - Supports Telescope (with multi-select) and `vim.ui.select` fallback
  - Used by all picker modules for consistent UX
- `picker.lua`: Workflow file picker (multi-select + preview)
- `buffer_utils.lua`: Buffer utility functions
- `github.lua`: GitHub API wrapper
- `workflow.lua`: Workflow file detection
- `url.lua`: URL builder and browser opener
  - Builds GitHub Actions URLs (workflow, run, job)
  - Opens URLs in browser via `vim.ui.open()`

**Supporting Modules**
- `cache.lua`: Simple in-memory cache (owner/repo → version)
- `lib/semver.lua`: Semantic version comparison
- `lib/highlights.lua`: Default highlight group setup

### File Activation (`ftplugin/yaml.lua`)

Auto-loads for GitHub Actions files and triggers version checks:
- On buffer enter (with 10ms defer)
- On text changes (`TextChanged`, `TextChangedI`)

### Data Flow

1. User opens `.github/workflows/*.yml`
2. `ftplugin/yaml.lua` triggers `check_versions()`
3. `parser.parse(bufnr)` extracts actions using treesitter
4. `checker.check_versions()` processes each action:
   - Check cache first
   - If not cached, call `github.fetch_latest_release()` async
   - Create `VersionInfo` objects with is_latest comparison
5. `display.show_versions()` renders virtual text with appropriate icons/highlights

### Type Annotations

The codebase uses LuaLS annotations extensively:
- `---@class` for type definitions
- `---@field` for class properties
- `---@param` and `---@return` for function signatures
- Key types: `Action`, `VersionInfo`, `VirtualTextOptions`

## Code Style

- **Formatter**: stylua with 120 column width, 2-space indentation, single quotes preferred
- **Linter**: luacheck configured via luarocks
- **Comments**: Focus on "why" not "what" - business logic and non-obvious implementations
- **Separation of Concerns**: Clear boundaries between parsing, business logic, and display

## Requirements

- Neovim 0.9+
- GitHub CLI (`gh`) installed and authenticated
- nvim-treesitter with YAML parser

## Testing Strategy

Tests are organized to mirror the source structure:
- `spec/versions/init_spec.lua` → `lua/github-actions/versions/init.lua`
- `spec/versions/parser_spec.lua` → `lua/github-actions/versions/parser.lua`
- `spec/shared/github_spec.lua` → `lua/github-actions/shared/github.lua`
- `spec/shared/select_spec.lua` → `lua/github-actions/shared/select.lua`
- `spec/watch/filter_spec.lua` → `lua/github-actions/watch/filter.lua`
- `spec/watch/run_picker_spec.lua` → `lua/github-actions/watch/run_picker.lua`
- `spec/watch/init_spec.lua` → `lua/github-actions/watch/init.lua`
- `spec/history/api_spec.lua` → `lua/github-actions/history/api.lua`
- `spec/history/init_spec.lua` → `lua/github-actions/history/init.lua`
- `spec/pr/api_spec.lua` → `lua/github-actions/pr/api.lua`
- `spec/pr/init_spec.lua` → `lua/github-actions/pr/init.lua`
- `spec/shared/url_spec.lua` → `lua/github-actions/shared/url.lua`
- Each module is tested independently with fixtures for API responses
- Integration tests verify end-to-end workflows with mocked external dependencies
