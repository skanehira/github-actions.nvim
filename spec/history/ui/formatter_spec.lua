dofile('spec/minimal_init.lua')

describe('history.ui.formatter', function()
  local formatter = require('github-actions.history.ui.formatter')

  describe('get_status_icon', function()
    describe('with default icons', function()
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
        it(
          string.format(
            'should return "%s" for status=%s, conclusion=%s',
            tc.expected,
            tc.status,
            tc.conclusion or 'nil'
          ),
          function()
            assert.equals(tc.expected, formatter.get_status_icon(tc.status, tc.conclusion))
          end
        )
      end
    end)

    describe('with custom icons', function()
      it('should use custom success icon', function()
        local custom_icons = { success = '[OK]' }
        assert.equals('[OK]', formatter.get_status_icon('completed', 'success', custom_icons))
      end)

      it('should use custom failure icon', function()
        local custom_icons = { failure = '[FAIL]' }
        assert.equals('[FAIL]', formatter.get_status_icon('completed', 'failure', custom_icons))
      end)

      it('should use custom cancelled icon', function()
        local custom_icons = { cancelled = '[CANCEL]' }
        assert.equals('[CANCEL]', formatter.get_status_icon('completed', 'cancelled', custom_icons))
      end)

      it('should use custom skipped icon', function()
        local custom_icons = { skipped = '[SKIP]' }
        assert.equals('[SKIP]', formatter.get_status_icon('completed', 'skipped', custom_icons))
      end)

      it('should use custom in_progress icon', function()
        local custom_icons = { in_progress = '[RUN]' }
        assert.equals('[RUN]', formatter.get_status_icon('in_progress', nil, custom_icons))
      end)

      it('should use custom queued icon', function()
        local custom_icons = { queued = '[QUEUE]' }
        assert.equals('[QUEUE]', formatter.get_status_icon('queued', nil, custom_icons))
      end)

      it('should use custom waiting icon', function()
        local custom_icons = { waiting = '[WAIT]' }
        assert.equals('[WAIT]', formatter.get_status_icon('waiting', nil, custom_icons))
      end)

      it('should use custom unknown icon', function()
        local custom_icons = { unknown = '[???]' }
        assert.equals('[???]', formatter.get_status_icon('unknown', nil, custom_icons))
      end)

      it('should fall back to default icons when custom icon is not provided', function()
        local custom_icons = { success = '[OK]' }
        -- failure icon not provided, should use default
        assert.equals('✗', formatter.get_status_icon('completed', 'failure', custom_icons))
      end)
    end)
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

    it('should format with custom icons', function()
      local run = {
        databaseId = 99999,
        displayTitle = 'custom icon test',
        headBranch = 'main',
        status = 'completed',
        conclusion = 'success',
        createdAt = '2025-10-19T10:00:00Z',
        updatedAt = '2025-10-19T10:03:00Z',
      }

      local custom_icons = { success = '[OK]' }
      local result = formatter.format_run(run, now, custom_icons)
      assert.matches('%[OK%]', result)
      assert.matches('#99999', result)
      assert.matches('custom icon test', result)
      -- Ensure default icon is NOT used
      assert.not_matches('✓', result)
    end)
  end)

  describe('format_job', function()
    it('should format completed job with duration', function()
      local job = {
        name = 'test (ubuntu-latest, stable)',
        status = 'completed',
        conclusion = 'success',
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = '2025-10-19T10:03:24Z',
      }

      local result = formatter.format_job(job)
      assert.matches('Job: test %(ubuntu%-latest, stable%)', result)
      assert.matches('✓', result)
      assert.matches('3m 24s', result)
    end)

    it('should format job with failure', function()
      local job = {
        name = 'build',
        status = 'completed',
        conclusion = 'failure',
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = '2025-10-19T10:01:45Z',
      }

      local result = formatter.format_job(job)
      assert.matches('Job: build', result)
      assert.matches('✗', result)
      assert.matches('1m 45s', result)
    end)

    it('should format in-progress job', function()
      local job = {
        name = 'deploy',
        status = 'in_progress',
        conclusion = nil,
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = nil,
      }

      local result = formatter.format_job(job)
      assert.matches('Job: deploy', result)
      assert.matches('⊙', result)
      assert.matches('%(running%)', result)
    end)

    it('should format with custom icons', function()
      local job = {
        name = 'lint',
        status = 'completed',
        conclusion = 'success',
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = '2025-10-19T10:00:12Z',
      }

      local custom_icons = { success = '[PASS]' }
      local result = formatter.format_job(job, custom_icons)
      assert.matches('%[PASS%]', result)
      assert.matches('Job: lint', result)
      assert.not_matches('✓', result)
    end)
  end)

  describe('format_step', function()
    it('should format completed step with duration', function()
      local step = {
        name = 'Run tests',
        status = 'completed',
        conclusion = 'success',
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = '2025-10-19T10:00:45Z',
      }

      local result = formatter.format_step(step, false)
      assert.matches('├─ ✓ Run tests', result)
      assert.matches('45s', result)
    end)

    it('should format last step with different prefix', function()
      local step = {
        name = 'Deploy',
        status = 'completed',
        conclusion = 'success',
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = '2025-10-19T10:01:30Z',
      }

      local result = formatter.format_step(step, true)
      assert.matches('└─ ✓ Deploy', result)
      assert.matches('1m 30s', result)
    end)

    it('should format failed step', function()
      local step = {
        name = 'Run tests',
        status = 'completed',
        conclusion = 'failure',
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = '2025-10-19T10:00:15Z',
      }

      local result = formatter.format_step(step, false)
      assert.matches('├─ ✗ Run tests', result)
      assert.matches('15s', result)
    end)

    it('should format skipped step', function()
      local step = {
        name = 'Deploy',
        status = 'completed',
        conclusion = 'skipped',
        startedAt = nil,
        completedAt = nil,
      }

      local result = formatter.format_step(step, true)
      assert.matches('└─ ⊘ Deploy', result)
      assert.matches('%(skipped%)', result)
    end)

    it('should format in-progress step', function()
      local step = {
        name = 'Build',
        status = 'in_progress',
        conclusion = nil,
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = nil,
      }

      local result = formatter.format_step(step, false)
      assert.matches('├─ ⊙ Build', result)
      assert.matches('%(running%)', result)
    end)

    it('should format with custom icons', function()
      local step = {
        name = 'Test',
        status = 'completed',
        conclusion = 'success',
        startedAt = '2025-10-19T10:00:00Z',
        completedAt = '2025-10-19T10:00:08Z',
      }

      local custom_icons = { success = '[V]' }
      local result = formatter.format_step(step, false, custom_icons)
      assert.matches('%[V%]', result)
      assert.matches('Test', result)
      assert.not_matches('✓', result)
    end)
  end)
end)
