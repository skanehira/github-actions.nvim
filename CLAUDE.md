# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin written in Lua that provides comprehensive GitHub Actions workflow management:
- **Version Checking**: Automatically checks GitHub Actions versions and displays them inline using extmarks
- **Workflow Dispatch**: Trigger workflows with `workflow_dispatch` support
- **Run History**: Browse workflow run history with expandable jobs and steps
- **Live Watch**: Monitor running workflow executions in real-time

The plugin automatically activates for `.github/workflows/*.yml` files and `.github/actions/*/action.yml` files, parsing them with treesitter and showing version information as virtual text at the end of each line.

## Development Commands

### Testing
```bash
# Run all tests
make test

# Run a specific test file
make test-file FILE=spec/parser_spec.lua

# Install test dependencies (nvim-treesitter)
make install-deps
```

### Code Quality
```bash
# Run linter (luacheck)
make lint

# Format code (stylua)
make format

# Check formatting without modifying files
make check
```

### Test Infrastructure
- Tests use busted framework with nlua
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
- `spec/versions/parser_spec.lua` → `lua/github-actions/versions/parser.lua`
- `spec/shared/github_spec.lua` → `lua/github-actions/shared/github.lua`
- `spec/watch/filter_spec.lua` → `lua/github-actions/watch/filter.lua`
- `spec/watch/run_picker_spec.lua` → `lua/github-actions/watch/run_picker.lua`
- `spec/watch/init_spec.lua` → `lua/github-actions/watch/init.lua`
- Each module is tested independently with fixtures for API responses
- Integration tests verify end-to-end workflows with mocked external dependencies


# AI-DLC and Spec-Driven Development

Kiro-style Spec Driven Development implementation on AI-DLC (AI Development Life Cycle)

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - Guide AI with project-wide rules and context
**Specs** (`.kiro/specs/`) - Formalize development process for individual features

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro:spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, but generate responses in Japanese (思考は英語、回答の生成は日本語で行うように)

## Minimal Workflow
- Phase 0 (optional): `/kiro:steering`, `/kiro:steering-custom`
- Phase 1 (Specification):
  - `/kiro:spec-init "description"`
  - `/kiro:spec-requirements {feature}`
  - `/kiro:validate-gap {feature}` (optional: for existing codebase)
  - `/kiro:spec-design {feature} [-y]`
  - `/kiro:validate-design {feature}` (optional: design review)
  - `/kiro:spec-tasks {feature} [-y]`
- Phase 2 (Implementation): `/kiro:spec-impl {feature} [tasks]`
  - `/kiro:validate-impl {feature}` (optional: after implementation)
- Progress check: `/kiro:spec-status {feature}` (use anytime)

## Development Rules
- 3-phase approval workflow: Requirements → Design → Tasks → Implementation
- Human review required each phase; use `-y` only for intentional fast-track
- Keep steering current and verify alignment with `/kiro:spec-status`

## Steering Configuration
- Load entire `.kiro/steering/` as project memory
- Default files: `product.md`, `tech.md`, `structure.md`
- Custom files are supported (managed via `/kiro:steering-custom`)

