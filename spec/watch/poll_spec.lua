dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field, need-check-nil

describe('watch.poll', function()
  local poll
  local api

  before_each(function()
    package.loaded['github-actions.watch.poll'] = nil
    package.loaded['github-actions.history.api'] = nil
    package.loaded['github-actions.watch.filter'] = nil

    poll = require('github-actions.watch.poll')
    api = require('github-actions.history.api')
  end)

  local running_run = {
    databaseId = 100,
    status = 'in_progress',
    headBranch = 'main',
    displayTitle = 'CI',
    createdAt = '2025-11-14T10:00:00Z',
  }

  local completed_run = {
    databaseId = 99,
    status = 'completed',
    headBranch = 'main',
    displayTitle = 'CI',
    createdAt = '2025-11-14T09:00:00Z',
  }

  describe('poll_running_runs', function()
    it('should invoke callback with running runs when first fetch finds them', function()
      local api_stub = stub(api, 'fetch_runs')
      api_stub.invokes(function(_, callback)
        callback({ completed_run, running_run }, nil)
      end)

      local result = nil
      poll.poll_running_runs('ci.yml', {}, function(running_runs, err)
        result = { running_runs = running_runs, err = err }
      end)

      assert.stub(api_stub).was_called(1)
      assert.stub(api_stub).was_called_with('ci.yml', match.is_function())
      assert.same({ running_run }, result.running_runs)
      assert.is_nil(result.err)

      api_stub:revert()
    end)

    it('should retry and invoke callback when running run appears on second fetch', function()
      local fetch_count = 0
      local api_stub = stub(api, 'fetch_runs')
      api_stub.invokes(function(_, callback)
        fetch_count = fetch_count + 1
        if fetch_count == 1 then
          callback({ completed_run }, nil)
        else
          callback({ running_run }, nil)
        end
      end)

      local result = nil
      poll.poll_running_runs('ci.yml', { interval_ms = 0 }, function(running_runs, err)
        result = { running_runs = running_runs, err = err }
      end)
      vim.wait(1000, function()
        return result ~= nil
      end)

      assert.stub(api_stub).was_called(2)
      assert.same({ running_run }, result.running_runs)
      assert.is_nil(result.err)

      api_stub:revert()
    end)

    it('should invoke callback with empty table after max attempts without running runs', function()
      local api_stub = stub(api, 'fetch_runs')
      api_stub.invokes(function(_, callback)
        callback({ completed_run }, nil)
      end)

      local result = nil
      poll.poll_running_runs('ci.yml', { interval_ms = 0, max_attempts = 3 }, function(running_runs, err)
        result = { running_runs = running_runs, err = err }
      end)
      vim.wait(1000, function()
        return result ~= nil
      end)

      assert.stub(api_stub).was_called(3)
      assert.same({}, result.running_runs)
      assert.is_nil(result.err)

      api_stub:revert()
    end)

    it('should invoke callback with error and stop retrying when fetch fails', function()
      local api_stub = stub(api, 'fetch_runs')
      api_stub.invokes(function(_, callback)
        callback(nil, 'API error: rate limit exceeded')
      end)

      local result = nil
      poll.poll_running_runs('ci.yml', { interval_ms = 0 }, function(running_runs, err)
        result = { running_runs = running_runs, err = err }
      end)
      vim.wait(100, function()
        return false
      end)

      assert.stub(api_stub).was_called(1)
      assert.is_nil(result.running_runs)
      assert.equals('API error: rate limit exceeded', result.err)

      api_stub:revert()
    end)
  end)
end)
