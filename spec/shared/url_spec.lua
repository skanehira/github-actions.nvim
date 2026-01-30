dofile('spec/minimal_init.lua')

describe('shared.url', function()
  local url = require('github-actions.shared.url')

  describe('build_workflow_url', function()
    it('should build correct workflow URL', function()
      local result = url.build_workflow_url('owner', 'repo', 'ci.yml')
      assert.equals('https://github.com/owner/repo/actions/workflows/ci.yml', result)
    end)

    it('should handle different workflow file names', function()
      local result = url.build_workflow_url('skanehira', 'github-actions.nvim', 'release.yaml')
      assert.equals('https://github.com/skanehira/github-actions.nvim/actions/workflows/release.yaml', result)
    end)
  end)

  describe('build_run_url', function()
    it('should build correct run URL', function()
      local result = url.build_run_url('owner', 'repo', 12345)
      assert.equals('https://github.com/owner/repo/actions/runs/12345', result)
    end)

    it('should handle large run IDs', function()
      local result = url.build_run_url('skanehira', 'github-actions.nvim', 9876543210)
      assert.equals('https://github.com/skanehira/github-actions.nvim/actions/runs/9876543210', result)
    end)
  end)

  describe('build_job_url', function()
    it('should build correct job URL', function()
      local result = url.build_job_url('owner', 'repo', 12345, 67890)
      assert.equals('https://github.com/owner/repo/actions/runs/12345/job/67890', result)
    end)

    it('should handle large IDs', function()
      local result = url.build_job_url('skanehira', 'github-actions.nvim', 21508428729, 61969476646)
      assert.equals('https://github.com/skanehira/github-actions.nvim/actions/runs/21508428729/job/61969476646', result)
    end)
  end)

  describe('get_repo_info', function()
    local stub = require('luassert.stub')

    it('should return error when gh command fails', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'not a git repository' })
      end)

      local called = false
      local result_owner, result_repo, result_err

      url.get_repo_info(function(owner, repo, err)
        called = true
        result_owner = owner
        result_repo = repo
        result_err = err
      end)

      assert.is_true(called)
      assert.is_nil(result_owner)
      assert.is_nil(result_repo)
      assert.is_not_nil(result_err)
      assert.matches('not a git repository', result_err)

      vim.system:revert()
    end)

    it('should parse repo info correctly', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 0, stdout = 'skanehira/github-actions.nvim\n', stderr = '' })
      end)

      local called = false
      local result_owner, result_repo, result_err

      url.get_repo_info(function(owner, repo, err)
        called = true
        result_owner = owner
        result_repo = repo
        result_err = err
      end)

      assert.is_true(called)
      assert.equals('skanehira', result_owner)
      assert.equals('github-actions.nvim', result_repo)
      assert.is_nil(result_err)

      vim.system:revert()
    end)

    it('should handle invalid output format', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 0, stdout = 'invalid-output', stderr = '' })
      end)

      local called = false
      local result_owner, result_repo, result_err

      url.get_repo_info(function(owner, repo, err)
        called = true
        result_owner = owner
        result_repo = repo
        result_err = err
      end)

      assert.is_true(called)
      assert.is_nil(result_owner)
      assert.is_nil(result_repo)
      assert.is_not_nil(result_err)
      assert.matches('Failed to parse repo info', result_err)

      vim.system:revert()
    end)
  end)

  describe('open_url', function()
    local stub = require('luassert.stub')

    it('should call vim.ui.open with the URL', function()
      stub(vim.ui, 'open')

      url.open_url('https://github.com/owner/repo')

      assert.stub(vim.ui.open).was_called_with('https://github.com/owner/repo')

      vim.ui.open:revert()
    end)
  end)
end)
