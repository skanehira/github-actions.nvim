dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

local fixture = require('spec.helpers.fixture')

--- Flush all pending vim.schedule callbacks
--- This is the official recommended way to process the fast_events queue
--- See: neovim/neovim src/nvim/README.md
local function flush_scheduled()
  vim.wait(0, function()
    return false
  end)
end

describe('workflow.history', function()
  local history = require('github-actions.history.api')
  local stub = require('luassert.stub')

  describe('fetch_runs', function()
    local test_cases = {
      {
        name = 'should parse successful run list response',
        fixture_name = 'history/runs_list',
        expected = {
          {
            conclusion = 'success',
            createdAt = '2025-10-18T04:09:29Z',
            databaseId = 18610558363,
            displayTitle = 'chore: improve test (#2)',
            headBranch = 'main',
            status = 'completed',
            updatedAt = '2025-10-18T04:10:30Z',
          },
          {
            conclusion = 'failure',
            createdAt = '2025-10-18T02:30:15Z',
            databaseId = 18610558362,
            displayTitle = 'fix: bug fix',
            headBranch = 'fix/bug',
            status = 'completed',
            updatedAt = '2025-10-18T02:31:45Z',
          },
          {
            conclusion = vim.NIL,
            createdAt = '2025-10-18T01:00:00Z',
            databaseId = 18610558361,
            displayTitle = 'feat: new feature',
            headBranch = 'main',
            status = 'in_progress',
            updatedAt = '2025-10-18T01:01:30Z',
          },
        },
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        stub(vim, 'system')
        local json_str = fixture.load(tc.fixture_name)
        vim.system.invokes(function(_, _, callback)
          callback({ code = 0, stdout = json_str, stderr = '' })
        end)

        local result_runs
        local result_err

        history.fetch_runs('test.yml', function(runs, err)
          result_runs = runs
          result_err = err
        end)

        -- Flush vim.schedule queue (non-blocking)
        flush_scheduled()

        -- Assert outside callback to ensure test failures are properly detected
        assert.is.not_nil(result_runs or result_err, 'Callback was not called')
        assert.is_nil(result_err)
        assert.are.same(tc.expected, result_runs)
      end)
    end

    it('should handle gh command not available', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 127, stdout = '', stderr = 'gh: command not found' })
      end)

      local result_runs
      local result_err

      history.fetch_runs('test.yml', function(runs, err)
        result_runs = runs
        result_err = err
      end)

      -- Flush vim.schedule queue (non-blocking)
      flush_scheduled()

      -- Assert outside callback
      assert.is.not_nil(result_runs or result_err, 'Callback was not called')
      assert.is_nil(result_runs)
      assert.is.not_nil(result_err)
      assert.matches('command not found', result_err)
    end)

    it('should handle invalid JSON response', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 0, stdout = 'invalid json', stderr = '' })
      end)

      local result_runs
      local result_err

      history.fetch_runs('test.yml', function(runs, err)
        result_runs = runs
        result_err = err
      end)

      -- Flush vim.schedule queue (non-blocking)
      flush_scheduled()

      -- Assert outside callback
      assert.is.not_nil(result_runs or result_err, 'Callback was not called')
      assert.is_nil(result_runs)
      assert.is.not_nil(result_err)
      assert.matches('Failed to parse', result_err)
    end)
  end)

  describe('fetch_jobs', function()
    local test_cases = {
      {
        name = 'should parse successful jobs response',
        fixture_name = 'history/run_jobs',
        run_id = 18610558363,
        expected = {
          jobs = {
            {
              completedAt = '2025-10-18T04:10:16Z',
              conclusion = 'success',
              databaseId = 53068027249,
              name = 'test (ubuntu-latest, stable)',
              startedAt = '2025-10-18T04:09:31Z',
              status = 'completed',
              steps = {
                {
                  completedAt = '2025-10-18T04:09:36Z',
                  conclusion = 'success',
                  name = 'Set up job',
                  number = 1,
                  startedAt = '2025-10-18T04:09:32Z',
                  status = 'completed',
                },
                {
                  completedAt = '2025-10-18T04:09:37Z',
                  conclusion = 'success',
                  name = 'Checkout code',
                  number = 2,
                  startedAt = '2025-10-18T04:09:36Z',
                  status = 'completed',
                },
                {
                  completedAt = '2025-10-18T04:10:14Z',
                  conclusion = 'failure',
                  name = 'Run tests',
                  number = 3,
                  startedAt = '2025-10-18T04:09:37Z',
                  status = 'completed',
                },
                {
                  completedAt = vim.NIL,
                  conclusion = 'skipped',
                  name = 'Deploy',
                  number = 4,
                  startedAt = vim.NIL,
                  status = 'completed',
                },
              },
              url = 'https://github.com/owner/repo/actions/runs/18610558363/job/53068027249',
            },
            {
              completedAt = '2025-10-18T04:10:20Z',
              conclusion = 'success',
              databaseId = 53068027250,
              name = 'lint',
              startedAt = '2025-10-18T04:09:33Z',
              status = 'completed',
              steps = {
                {
                  completedAt = '2025-10-18T04:09:35Z',
                  conclusion = 'success',
                  name = 'Set up job',
                  number = 1,
                  startedAt = '2025-10-18T04:09:33Z',
                  status = 'completed',
                },
                {
                  completedAt = '2025-10-18T04:10:20Z',
                  conclusion = 'success',
                  name = 'Run linter',
                  number = 2,
                  startedAt = '2025-10-18T04:09:35Z',
                  status = 'completed',
                },
              },
              url = 'https://github.com/owner/repo/actions/runs/18610558363/job/53068027250',
            },
          },
        },
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        stub(vim, 'system')
        local json_str = fixture.load(tc.fixture_name)
        vim.system.invokes(function(_, _, callback)
          callback({ code = 0, stdout = json_str, stderr = '' })
        end)

        local result_jobs
        local result_err

        history.fetch_jobs(tc.run_id, function(jobs, err)
          result_jobs = jobs
          result_err = err
        end)

        -- Flush vim.schedule queue (non-blocking)
        flush_scheduled()

        -- Assert outside callback to ensure test failures are properly detected
        assert.is.not_nil(result_jobs or result_err, 'Callback was not called')
        assert.is_nil(result_err)
        assert.are.same(tc.expected, result_jobs)
      end)
    end

    it('should handle gh command error', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'API error' })
      end)

      local result_jobs
      local result_err

      history.fetch_jobs(123, function(jobs, err)
        result_jobs = jobs
        result_err = err
      end)

      -- Flush vim.schedule queue (non-blocking)
      flush_scheduled()

      -- Assert outside callback
      assert.is.not_nil(result_jobs or result_err, 'Callback was not called')
      assert.is_nil(result_jobs)
      assert.is.not_nil(result_err)
      assert.matches('API error', result_err)
    end)

    it('should handle invalid JSON response', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 0, stdout = 'invalid json', stderr = '' })
      end)

      local result_jobs
      local result_err

      history.fetch_jobs(123, function(jobs, err)
        result_jobs = jobs
        result_err = err
      end)

      -- Flush vim.schedule queue (non-blocking)
      flush_scheduled()

      -- Assert outside callback
      assert.is.not_nil(result_jobs or result_err, 'Callback was not called')
      assert.is_nil(result_jobs)
      assert.is.not_nil(result_err)
      assert.matches('Failed to parse', result_err)
    end)
  end)

  describe('fetch_logs', function()
    local test_cases = {
      {
        name = 'should fetch logs successfully',
        fixture_name = 'history/job_logs',
        run_id = 18610558363,
        job_id = 53068027249,
        expected_lines = 21, -- Number of lines in fixture (including trailing newline)
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        stub(vim, 'system')
        local logs_content = fixture.load(tc.fixture_name, 'txt')
        vim.system.invokes(function(_, _, callback)
          callback({ code = 0, stdout = logs_content, stderr = '' })
        end)

        local result_logs
        local result_err

        history.fetch_logs(tc.run_id, tc.job_id, function(logs, err)
          result_logs = logs
          result_err = err
        end)

        -- Flush vim.schedule queue (non-blocking)
        flush_scheduled()

        -- Assert outside callback to ensure test failures are properly detected
        assert.is.not_nil(result_logs or result_err, 'Callback was not called')
        assert.is_nil(result_err)
        assert.is_not_nil(result_logs)

        -- Check that logs content is returned
        local lines = vim.split(result_logs, '\n', { plain = true })
        assert.equals(tc.expected_lines, #lines)
      end)
    end

    it('should handle gh command error', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'Failed to fetch logs' })
      end)

      local result_logs
      local result_err

      history.fetch_logs(123, 456, function(logs, err)
        result_logs = logs
        result_err = err
      end)

      -- Flush vim.schedule queue (non-blocking)
      flush_scheduled()

      -- Assert outside callback
      assert.is.not_nil(result_logs or result_err, 'Callback was not called')
      assert.is_nil(result_logs)
      assert.is.not_nil(result_err)
      assert.matches('Failed to fetch logs', result_err)
    end)
  end)

  describe('rerun', function()
    it('should call gh run rerun with correct arguments', function()
      stub(vim, 'system')
      vim.system.invokes(function(cmd, _, callback)
        -- Verify correct command is called
        assert.are.same({ 'gh', 'run', 'rerun', '12345' }, cmd)
        callback({ code = 0, stdout = '', stderr = '' })
      end)

      local callback_called = false
      local result_err

      history.rerun(12345, function(err)
        callback_called = true
        result_err = err
      end)

      flush_scheduled()

      assert.is_true(callback_called, 'Callback was not called')
      assert.is_nil(result_err)
    end)

    it('should call gh run rerun with --failed flag when failed_only is true', function()
      stub(vim, 'system')
      vim.system.invokes(function(cmd, _, callback)
        -- Verify --failed flag is included
        assert.are.same({ 'gh', 'run', 'rerun', '12345', '--failed' }, cmd)
        callback({ code = 0, stdout = '', stderr = '' })
      end)

      local callback_called = false
      local result_err

      history.rerun(12345, function(err)
        callback_called = true
        result_err = err
      end, { failed_only = true })

      flush_scheduled()

      assert.is_true(callback_called, 'Callback was not called')
      assert.is_nil(result_err)
    end)

    it('should call gh run rerun without --failed flag when failed_only is false', function()
      stub(vim, 'system')
      vim.system.invokes(function(cmd, _, callback)
        -- Verify --failed flag is NOT included
        assert.are.same({ 'gh', 'run', 'rerun', '12345' }, cmd)
        callback({ code = 0, stdout = '', stderr = '' })
      end)

      local callback_called = false
      local result_err

      history.rerun(12345, function(err)
        callback_called = true
        result_err = err
      end, { failed_only = false })

      flush_scheduled()

      assert.is_true(callback_called, 'Callback was not called')
      assert.is_nil(result_err)
    end)

    it('should handle gh command error', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'run 12345 cannot be rerun' })
      end)

      local callback_called = false
      local result_err

      history.rerun(12345, function(err)
        callback_called = true
        result_err = err
      end)

      flush_scheduled()

      assert.is_true(callback_called, 'Callback was not called')
      assert.is.not_nil(result_err)
      assert.matches('cannot be rerun', result_err)
    end)
  end)

  describe('fetch_runs_by_branch', function()
    it('should fetch runs filtered by branch', function()
      stub(vim, 'system')
      local json_response = vim.fn.json_encode({
        {
          conclusion = 'success',
          createdAt = '2025-01-01T00:00:00Z',
          databaseId = 12345,
          displayTitle = 'CI',
          headBranch = 'feature/test',
          status = 'completed',
          updatedAt = '2025-01-01T00:10:00Z',
        },
      })
      vim.system.invokes(function(cmd, _, callback)
        -- Verify --branch flag is included
        assert.is_true(vim.tbl_contains(cmd, '--branch'))
        assert.is_true(vim.tbl_contains(cmd, 'feature/test'))
        callback({ code = 0, stdout = json_response, stderr = '' })
      end)

      local result_runs
      local result_err

      history.fetch_runs_by_branch('feature/test', function(runs, err)
        result_runs = runs
        result_err = err
      end)

      flush_scheduled()

      assert.is_nil(result_err)
      assert.is.not_nil(result_runs)
      assert.equals(1, #result_runs)
      assert.equals('feature/test', result_runs[1].headBranch)
    end)

    it('should handle gh command error', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'API error' })
      end)

      local result_runs
      local result_err

      history.fetch_runs_by_branch('main', function(runs, err)
        result_runs = runs
        result_err = err
      end)

      flush_scheduled()

      assert.is_nil(result_runs)
      assert.is.not_nil(result_err)
      assert.matches('API error', result_err)
    end)
  end)

  describe('cancel', function()
    it('should call gh run cancel with correct arguments', function()
      stub(vim, 'system')
      vim.system.invokes(function(cmd, _, callback)
        -- Verify correct command is called
        assert.are.same({ 'gh', 'run', 'cancel', '12345' }, cmd)
        callback({ code = 0, stdout = '', stderr = '' })
      end)

      local callback_called = false
      local result_err

      history.cancel(12345, function(err)
        callback_called = true
        result_err = err
      end)

      flush_scheduled()

      assert.is_true(callback_called, 'Callback was not called')
      assert.is_nil(result_err)
    end)

    it('should handle gh command error for non-cancellable run', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'run 12345 cannot be cancelled' })
      end)

      local callback_called = false
      local result_err

      history.cancel(12345, function(err)
        callback_called = true
        result_err = err
      end)

      flush_scheduled()

      assert.is_true(callback_called, 'Callback was not called')
      assert.is.not_nil(result_err)
      assert.matches('cannot be cancelled', result_err)
    end)
  end)
end)
