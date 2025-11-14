# Technology Stack

## Architecture

**Modular Feature Architecture**: Three independent feature modules (`versions`, `dispatch`, `history`) with shared utilities. Each module has its own `init.lua` entry point and sub-modules for parsing, API, and UI concerns.

**Async Callback Pattern**: Uses `vim.system()` for non-blocking gh CLI calls with callback-based result handling. No external async libraries - relies on Neovim's built-in async capabilities.

## Core Technologies

- **Language**: Lua (Neovim 0.9+)
- **Parser**: nvim-treesitter (YAML grammar for workflow parsing)
- **External Tool**: GitHub CLI (`gh`) for all GitHub API interactions
- **UI Enhancement**: telescope.nvim (optional, for enhanced workflow selection with preview/multi-select)

## Key Libraries

- **nvim-treesitter**: Query-based parsing of YAML workflow files to extract action references
- **telescope.nvim**: Optional dependency for enhanced pickers (falls back to `vim.ui.select`)

## Development Standards

### Type Safety
- **LuaLS Annotations**: Extensive use of `---@class`, `---@field`, `---@param`, `---@return` for type documentation
- **Explicit Type Definitions**: Core types defined as classes (e.g., `Action`, `VersionInfo`, `GithubActionsConfig`)

### Code Quality
- **Linter**: luacheck with Neovim-specific globals configured (`.luacheckrc`)
- **Formatter**: stylua with 120-column width, 2-space indentation, single quotes preferred (`stylua.toml`)

### Testing
- **Framework**: busted with nlua (Lua test runner for Neovim)
- **Structure**: Mirrors source structure (`spec/versions/parser_spec.lua` ↔ `lua/github-actions/versions/parser.lua`)
- **Fixtures**: Test data in `spec/fixtures/`, shared helpers in `spec/helpers/`
- **Isolation**: Each test loads minimal Neovim environment via `spec/minimal_init.lua`

## Development Environment

### Required Tools
- Neovim 0.9+
- GitHub CLI (`gh`) - authenticated
- Docker (for running tests in isolated environment)
- stylua (for code formatting)
- luacheck (for linting, installed in Docker)

### Common Commands
```bash
# Test: Docker-based test runner
make test
make test-file FILE=spec/versions/parser_spec.lua

# Quality: Local formatting and checks
make format      # Format with stylua
make check       # Check formatting
make lint        # Run luacheck (in Docker)
```

## Key Technical Decisions

**gh CLI Over REST API**: Delegates authentication, rate limiting, and API versioning to the official GitHub CLI rather than implementing HTTP client logic.

**Treesitter Query Parsing**: Uses structured queries instead of regex for reliable YAML parsing, enabling accurate extraction of action owner/repo/version even in complex workflow files.

**Virtual Text for Version Display**: Uses Neovim extmarks (namespace-isolated) for non-intrusive inline display rather than modifying file content or using floating windows.

**Modular Feature Isolation**: Each major feature (`versions`, `dispatch`, `history`) is self-contained with minimal cross-dependencies, allowing features to be tested and developed independently.

---
_Created: 2025-11-12_
