dofile('spec/minimal_init.lua')

describe('history.ui.formatter', function()
  local formatter = require('github-actions.history.ui.formatter')

  describe('get_status_icon', function()
    local test_cases = {
      { status = 'completed', conclusion = 'success', expected = '✓' },
      { status = 'completed', conclusion = 'failure', expected = '✗' },
      { status = 'completed', conclusion = 'cancelled', expected = '⊘' },
      { status = 'completed', conclusion = 'skipped', expected = '⊘' },
      { status = 'in_progress', conclusion = nil, expected = '⊙' },
      { status = 'queued', conclusion = nil, expected = '○' },
      { status = 'waiting', conclusion = nil, expected = '○' },
      { status = 'unknown', conclusion = nil, expected = '?' },
    }

    for _, tc in ipairs(test_cases) do
      it(string.format('should return "%s" for status=%s, conclusion=%s', tc.expected, tc.status, tc.conclusion or 'nil'), function()
        assert.equals(tc.expected, formatter.get_status_icon(tc.status, tc.conclusion))
      end)
    end
  end)

  describe('format_run', function()
    -- Mock time for consistent testing
    local now = os.time({ year = 2025, month = 10, day = 19, hour = 12, min = 0, sec = 0 })

    it('should format a successful run', function()
      local run = {
        databaseId = 12345,
        displayTitle = 'feat: add new feature',
        headBranch = 'main',
        status = 'completed',
        conclusion = 'success',
        createdAt = '2025-10-19T10:00:00Z',
        updatedAt = '2025-10-19T10:05:24Z',
      }

      local result = formatter.format_run(run, now)
      -- Format: ✓ #12345 main: feat: add new feature    2h ago    5m 24s
      assert.matches('✓', result)
      assert.matches('#12345', result)
      assert.matches('main:', result)
      assert.matches('feat: add new feature', result)
      assert.matches('2h ago', result)
      assert.matches('5m 24s', result)
    end)

    it('should format a failed run', function()
      local run = {
        databaseId = 12346,
        displayTitle = 'fix: critical bug',
        headBranch = 'fix/bug',
        status = 'completed',
        conclusion = 'failure',
        createdAt = '2025-10-19T11:50:00Z',
        updatedAt = '2025-10-19T11:51:45Z',
      }

      local result = formatter.format_run(run, now)
      assert.matches('✗', result)
    end)

    it('should format an in-progress run', function()
      local run = {
        databaseId = 12347,
        displayTitle = 'test: add tests',
        headBranch = 'feature/test',
        status = 'in_progress',
        conclusion = vim.NIL, -- JSON null
        createdAt = '2025-10-19T11:58:30Z',
        updatedAt = '2025-10-19T11:59:00Z',
      }

      local result = formatter.format_run(run, now)
      assert.matches('⊙', result)
      assert.matches('#12347', result)
      assert.matches('%(running%)', result)
    end)
  end)
end)
