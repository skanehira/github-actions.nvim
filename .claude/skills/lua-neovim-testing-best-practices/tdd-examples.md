# TDD Implementation Examples

This document provides real-world examples from the codebase showing how to apply the TDD workflow described in [Implementing Features with TDD](./SKILL.md).

## Complete Example: "Newer Than Latest" Error Display

This example shows the full TDD cycle for adding error display when a user specifies a version newer than the latest available version.

### Initial Requirement

**User Request**: "Display an error when the input version is newer than the latest version"

### Phase 1: Requirements Clarification

**Questions asked using AskUserQuestion**:

1. **Display method**:
   - ✅ Selected: Use error icon (🔴)
   - Alternative: Use warning icon (⚠️)

2. **Error message**:
   - ✅ Selected: "newer than latest"
   - Alternative: "invalid version"

3. **Highlight group**:
   - ✅ Selected: `GitHubActionsVersionError`
   - Alternative: `GitHubActionsVersionOutdated`

### Phase 2: Analysis

**Existing code investigation** (using serena tools):

```lua
-- Found: semver.compare() returns boolean
-- Location: lua/github-actions/lib/semver.lua:33-59

-- Found: checker.lua uses semver.compare()
-- Location: lua/github-actions/workflow/checker.lua:26

-- Found: display.lua handles error display
-- Location: lua/github-actions/display.lua:98-102
```

**Key insight**: Need to change `compare()` from boolean to detailed status.

### Phase 3: RED Phase - Write Failing Tests

**File**: `spec/lib/semver_spec.lua`

Added 19 new test cases:

```lua
describe('get_version_status', function()
  local test_cases = {
    -- Newer cases (NEW BEHAVIOR)
    {
      name = 'should return "newer" when current major is newer',
      current = 'v4.0.0',
      latest = 'v3.9.9',
      expected = 'newer',
    },
    {
      name = 'should return "newer" when current minor is newer',
      current = 'v3.6.0',
      latest = 'v3.5.9',
      expected = 'newer',
    },
    {
      name = 'should return "newer" when current patch is newer',
      current = 'v3.5.2',
      latest = 'v3.5.1',
      expected = 'newer',
    },
    -- Latest cases
    {
      name = 'should return "latest" when versions are equal',
      current = 'v3.5.1',
      latest = 'v3.5.1',
      expected = 'latest',
    },
    -- Outdated cases
    {
      name = 'should return "outdated" when current major is older',
      current = 'v3.0.0',
      latest = 'v4.0.0',
      expected = 'outdated',
    },
    -- Invalid cases
    {
      name = 'should return "invalid" when current is nil',
      current = nil,
      latest = 'v3.5.1',
      expected = 'invalid',
    },
    -- ... 13 more test cases
  }

  for _, tc in ipairs(test_cases) do
    it(tc.name, function()
      local status = semver.get_version_status(tc.current, tc.latest)
      assert.are.equal(tc.expected, status)
    end)
  end
end)
```

**Test result** (RED phase):
```bash
$ make test
...
19 errors / 81 successes
Error: attempt to call field 'get_version_status' (a nil value)
```

✅ Tests failed as expected - RED phase complete.

### Phase 4: GREEN Phase - Minimal Implementation

**File**: `lua/github-actions/lib/semver.lua`

Added new function:

```lua
---Get version status by comparing current and latest versions
---@param current_version string|nil Current version (e.g., "v3", "v3.5", "v3.5.1")
---@param latest_version string|nil Latest available version
---@return string status "newer"|"latest"|"outdated"|"invalid"
function M.get_version_status(current_version, latest_version)
  local curr_parts = M.parse(current_version)
  local latest_parts = M.parse(latest_version)

  -- If parsing failed, return invalid
  if #curr_parts == 0 or #latest_parts == 0 then
    return 'invalid'
  end

  -- Compare only the depth of current version
  local depth = #curr_parts

  for i = 1, depth do
    local curr = curr_parts[i] or 0
    local latest = latest_parts[i] or 0

    if curr < latest then
      return 'outdated'
    elseif curr > latest then
      return 'newer'  -- NEW: Detect newer versions
    end
  end

  return 'latest'
end
```

**Test result** (GREEN phase):
```bash
$ make test
...
100 successes / 0 failures / 0 errors
```

✅ All tests passed - GREEN phase complete.

### Phase 5: REFACTOR Phase - Improve Code Quality

Refactored existing `compare()` to use new function:

```lua
---Compare versions with appropriate depth
---@param current_version string|nil Current version
---@param latest_version string|nil Latest available version
---@return boolean is_latest True if current is up-to-date
function M.compare(current_version, latest_version)
  local status = M.get_version_status(current_version, latest_version)
  return status == 'latest' or status == 'newer'
end
```

**Benefits**:
- Eliminated code duplication
- Single source of truth for version comparison
- Backward compatible (existing tests still pass)

**Test result** (after refactor):
```bash
$ make test
...
100 successes / 0 failures / 0 errors
```

✅ Refactoring maintained green tests.

### Phase 6: Integration

**File**: `lua/github-actions/workflow/checker.lua`

Updated `create_version_info()` to handle new status:

```lua
local function create_version_info(action, latest_version, error_msg)
  local version_info = {
    line = action.line,
    col = action.col,
    current_version = action.version,
    latest_version = latest_version,
    is_latest = false,
    error = error_msg,
  }

  if not error_msg and latest_version and action.version then
    local status = semver.get_version_status(action.version, latest_version)

    if status == 'newer' then
      -- NEW: Treat "newer" as error
      version_info.error = 'newer than latest'
      version_info.is_latest = false
    elseif status == 'latest' then
      version_info.is_latest = true
    else -- 'outdated' or 'invalid'
      version_info.is_latest = false
    end
  end

  return version_info
end
```

### Phase 7: Quality Gates

**All checks passed**:

```bash
$ make check
# ✅ No formatting issues

$ make lint
# ✅ 0 warnings / 0 errors in 8 files

$ make test
# ✅ 100 successes / 0 failures / 0 errors
```

### Phase 8: Display Verification

**How it works**:

When `version_info.error` is set, `display.lua` automatically:

```lua
-- File: lua/github-actions/display.lua:98-102
if version_info.error then
  table.insert(virt_text, { opts.icons.error, opts.highlight_icon_error })
  table.insert(virt_text, { ' ' .. version_info.error, opts.highlight_error })
  return virt_text
end
```

**Result**:
```yaml
- uses: actions/checkout@v5  # Latest is v4.0.0
# Display: 🔴 newer than latest
```

### Commit

```
✨ feat: add error display for versions newer than latest

Add detailed version status detection to identify when the current
version is newer than the latest available version, which indicates
a potential configuration error.

Changes:
- Add get_version_status() function returning "newer"|"latest"|"outdated"|"invalid"
- Update checker.lua to treat "newer" status as error with message "newer than latest"
- Display error icon (🔴) and GitHubActionsVersionError highlight for newer versions
- Refactor compare() to use the new status function
- Add comprehensive test coverage for all version status scenarios (19 test cases)

Why this matters:
Users may mistakenly specify a version that doesn't exist yet, and this
change helps catch those configuration errors early by displaying them
as errors in the editor.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Key Takeaways

1. **Clarify first**: Asked 3 specific questions before implementation
2. **Test first**: Wrote 19 test cases before any code
3. **Minimal implementation**: Added just enough code to pass tests
4. **Refactor safely**: Improved code while keeping tests green
5. **Integration**: Updated caller code to use new behavior
6. **Quality gates**: All checks passed before commit

## Common Patterns Demonstrated

### Pattern 1: Status-Based Return Values

```lua
-- Instead of boolean:
function compare() return true/false end

-- Use descriptive status:
function get_status() return "newer"|"latest"|"outdated"|"invalid" end
```

**Benefits**: More expressive, easier to extend, clearer intent.

### Pattern 2: Data-Driven Tests

```lua
local test_cases = {
  { name = "...", input = "...", expected = "..." },
  { name = "...", input = "...", expected = "..." },
}

for _, tc in ipairs(test_cases) do
  it(tc.name, function()
    assert.are.equal(tc.expected, func(tc.input))
  end)
end
```

**Benefits**: Easy to add cases, clear test intent, maintainable.

### Pattern 3: Error Field Pattern

```lua
-- Set error on data structure
version_info.error = "error message"

-- Display layer handles automatically
if version_info.error then
  display_error(version_info.error)
end
```

**Benefits**: Separation of concerns, reusable display logic.

## Testing Tips

### Organize Test Cases by Category

```lua
local test_cases = {
  -- Normal behavior
  { ... },
  { ... },
  -- Edge cases (empty strings, boundaries)
  { ... },
  { ... },
  -- Error cases (nil, invalid input)
  { ... },
  { ... },
}
```

### Use Descriptive Test Names

```lua
-- ❌ Bad
it('test1', ...)

-- ✅ Good
it('should return "newer" when current major is newer', ...)
```

### Cover All Status Paths

```lua
-- For a 4-state return value, ensure:
-- - At least 1 test for each state
-- - Edge cases within each state
-- - Boundary conditions between states
```

## Next Steps

For more TDD patterns and practices, refer to:
- Project's `spec/` directory for more examples
- [Implementing Features with TDD](./implementing-features-with-tdd.md) for the full workflow
- CLAUDE.md for project-wide TDD requirements
