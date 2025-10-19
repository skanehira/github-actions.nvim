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
  local history = require('github-actions.workflow.history')
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
end)
