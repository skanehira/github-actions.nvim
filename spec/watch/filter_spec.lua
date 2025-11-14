dofile('spec/minimal_init.lua')

describe('watch.filter', function()
  local filter

  before_each(function()
    -- Module will be created, but doesn't exist yet (RED phase)
    filter = require('github-actions.watch.filter')
  end)

  describe('filter_running_runs', function()
    it('should filter runs with in_progress status', function()
      local runs = {
        {
          databaseId = 1,
          status = 'in_progress',
          headBranch = 'main',
          displayTitle = 'CI',
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 2,
          status = 'completed',
          headBranch = 'feature',
          displayTitle = 'Build',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local result = filter.filter_running_runs(runs)

      assert.equals(1, #result)
      assert.equals(1, result[1].databaseId)
      assert.equals('in_progress', result[1].status)
    end)

    it('should filter runs with queued status', function()
      local runs = {
        {
          databaseId = 1,
          status = 'queued',
          headBranch = 'main',
          displayTitle = 'CI',
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 2,
          status = 'completed',
          headBranch = 'feature',
          displayTitle = 'Build',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local result = filter.filter_running_runs(runs)

      assert.equals(1, #result)
      assert.equals(1, result[1].databaseId)
      assert.equals('queued', result[1].status)
    end)

    it('should include both in_progress and queued runs', function()
      local runs = {
        {
          databaseId = 1,
          status = 'in_progress',
          headBranch = 'main',
          displayTitle = 'CI',
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 2,
          status = 'queued',
          headBranch = 'feature',
          displayTitle = 'Build',
          createdAt = '2025-11-14T11:00:00Z',
        },
        {
          databaseId = 3,
          status = 'completed',
          headBranch = 'hotfix',
          displayTitle = 'Deploy',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local result = filter.filter_running_runs(runs)

      assert.equals(2, #result)
      -- Should be sorted by createdAt descending (newest first)
      assert.equals(2, result[1].databaseId) -- 11:00
      assert.equals(1, result[2].databaseId) -- 10:00
    end)

    it('should return empty array when no running runs', function()
      local runs = {
        {
          databaseId = 1,
          status = 'completed',
          headBranch = 'main',
          displayTitle = 'CI',
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 2,
          status = 'failure',
          headBranch = 'feature',
          displayTitle = 'Build',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local result = filter.filter_running_runs(runs)

      assert.equals(0, #result)
    end)

    it('should handle empty array input', function()
      local runs = {}

      local result = filter.filter_running_runs(runs)

      assert.equals(0, #result)
    end)

    it('should handle nil input', function()
      local result = filter.filter_running_runs(nil)

      assert.equals(0, #result)
    end)

    it('should handle runs with missing fields gracefully', function()
      local runs = {
        {
          databaseId = 1,
          status = 'in_progress',
          headBranch = 'main',
          -- missing displayTitle
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 2,
          status = 'queued',
          -- missing headBranch
          displayTitle = 'Build',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local result = filter.filter_running_runs(runs)

      assert.equals(2, #result)
    end)

    it('should sort by createdAt descending (newest first)', function()
      local runs = {
        {
          databaseId = 1,
          status = 'in_progress',
          headBranch = 'oldest',
          displayTitle = 'CI',
          createdAt = '2025-11-14T08:00:00Z',
        },
        {
          databaseId = 2,
          status = 'queued',
          headBranch = 'middle',
          displayTitle = 'Build',
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 3,
          status = 'in_progress',
          headBranch = 'newest',
          displayTitle = 'Deploy',
          createdAt = '2025-11-14T12:00:00Z',
        },
      }

      local result = filter.filter_running_runs(runs)

      assert.equals(3, #result)
      assert.equals(3, result[1].databaseId) -- newest (12:00)
      assert.equals(2, result[2].databaseId) -- middle (10:00)
      assert.equals(1, result[3].databaseId) -- oldest (08:00)
    end)
  end)
end)
