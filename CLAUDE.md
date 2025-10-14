# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin written in Lua that checks GitHub Actions versions and displays them inline using extmarks. The plugin automatically activates for `.github/workflows/*.yml` files and `.github/actions/*/action.yml` files, parsing them with treesitter and showing version information as virtual text at the end of each line.

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
- `spec/workflow/parser_spec.lua` → `lua/github-actions/workflow/parser.lua`
- `spec/github_spec.lua` → `lua/github-actions/github.lua`
- Each module is tested independently with fixtures for API responses
