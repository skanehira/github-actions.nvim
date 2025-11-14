# Project Structure

## Organization Philosophy

**Feature-First Modular Architecture**: Code is organized by feature (`versions`, `dispatch`, `history`) rather than technical layer. Each feature module contains its own business logic, UI components, and sub-modules. Shared utilities are centralized in `shared/` and `lib/` directories.

## Directory Patterns

### Feature Modules (`lua/github-actions/{feature}/`)
**Location**: `/lua/github-actions/versions/`, `/lua/github-actions/dispatch/`, `/lua/github-actions/history/`
**Purpose**: Independent feature implementations with init.lua entry point
**Example**:
```
versions/
  init.lua          # Public API (check_versions)
  parser.lua        # Treesitter YAML parsing
  checker.lua       # Business logic coordination
  cache.lua         # In-memory version cache
  ui/
    display.lua     # Virtual text rendering
```

### Shared Modules (`lua/github-actions/shared/`)
**Location**: `/lua/github-actions/shared/`
**Purpose**: Cross-feature utilities used by multiple modules
**Example**: `github.lua` (gh CLI wrapper), `workflow.lua` (workflow file detection), `picker.lua` (file picker abstraction)

### Library Modules (`lua/github-actions/lib/`)
**Location**: `/lua/github-actions/lib/`
**Purpose**: Pure utility functions with no Neovim or plugin-specific dependencies
**Example**: `semver.lua` (version comparison), `time.lua` (timestamp formatting), `git.lua` (git operations)

### Test Structure (`spec/`)
**Location**: `/spec/`
**Purpose**: Mirrors source structure for 1:1 mapping
**Example**: `spec/versions/parser_spec.lua` tests `lua/github-actions/versions/parser.lua`

### Auto-Activation (`ftplugin/`)
**Location**: `/ftplugin/yaml.lua`
**Purpose**: Auto-detect GitHub Actions files and trigger version checking on buffer events

## Naming Conventions

- **Files**: `snake_case.lua` for all Lua modules
- **Modules**: Descriptive names matching purpose (`parser.lua`, `checker.lua`, `display.lua`)
- **Test Files**: Source name + `_spec.lua` suffix (e.g., `parser_spec.lua`)
- **UI Modules**: Grouped in `ui/` subdirectories within features

## Import Organization

```lua
-- Feature-local imports (relative)
local parser = require('github-actions.versions.parser')

-- Cross-feature shared imports (absolute)
local github = require('github-actions.shared.github')
local highlights = require('github-actions.lib.highlights')

-- External dependencies
local ts_utils = require('nvim-treesitter.ts_utils')
```

**Pattern**: Use full module paths from `github-actions` root. No path aliases configured.

## Code Organization Principles

**Separation of Concerns**: Each module has a single responsibility:
- `parser.lua` extracts data (treesitter queries)
- `checker.lua` coordinates business logic (caching, API calls, version comparison)
- `display.lua` handles presentation (extmarks, virtual text)
- `github.lua` wraps external tool (gh CLI)

**Data Flow**: Unidirectional flow within features:
1. Parse (extract structured data from buffer)
2. Process (async API calls, business logic)
3. Present (UI rendering)

**Dependency Direction**:
- Feature modules → Shared/Lib modules ✓
- Shared/Lib modules → Feature modules ✗
- Features are independent of each other

**Type Annotations**: Define types at module boundaries using LuaLS annotations for clear contracts between modules.

---
_Created: 2025-11-12_
