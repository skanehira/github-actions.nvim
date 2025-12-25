dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

local fixture = require('spec.helpers.fixture')

--- Flush all pending vim.schedule callbacks
local function flush_scheduled()
  vim.wait(0, function()
    return false
  end)
end

describe('pr.api', function()
  local api
  local stub = require('luassert.stub')

  before_each(function()
    package.loaded['github-actions.pr.api'] = nil
    api = require('github-actions.pr.api')
  end)

  describe('get_current_branch', function()
    it('should return current branch name', function()
      stub(vim.fn, 'system')
      vim.fn.system.returns('feature/my-branch\n')

      local branch = api.get_current_branch()

      assert.equals('feature/my-branch', branch)
      assert.stub(vim.fn.system).was_called_with('git branch --show-current')

      vim.fn.system:revert()
    end)

    it('should return nil when not in a git repository', function()
      stub(vim.fn, 'system')
      vim.fn.system.returns('')

      local branch = api.get_current_branch()

      assert.is_nil(branch)

      vim.fn.system:revert()
    end)
  end)

  describe('fetch_remote_branches', function()
    it('should return list of remote branches', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({
          code = 0,
          stdout = 'origin/main\norigin/feature/branch-1\norigin/feature/branch-2\n',
          stderr = '',
        })
      end)

      local result_branches
      local result_err

      api.fetch_remote_branches(function(branches, err)
        result_branches = branches
        result_err = err
      end)

      flush_scheduled()

      assert.is_nil(result_err)
      assert.are.same({ 'main', 'feature/branch-1', 'feature/branch-2' }, result_branches)
    end)

    it('should handle git command error', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'fatal: not a git repository' })
      end)

      local result_branches
      local result_err

      api.fetch_remote_branches(function(branches, err)
        result_branches = branches
        result_err = err
      end)

      flush_scheduled()

      assert.is_nil(result_branches)
      assert.is.not_nil(result_err)
      assert.matches('not a git repository', result_err)
    end)
  end)

  describe('fetch_open_prs', function()
    it('should return list of open PRs', function()
      stub(vim, 'system')
      local json_response = vim.fn.json_encode({
        {
          number = 1,
          title = 'Fix bug',
          headRefName = 'fix/bug',
          state = 'OPEN',
          url = 'https://github.com/owner/repo/pull/1',
        },
        {
          number = 2,
          title = 'Add feature',
          headRefName = 'feature/new',
          state = 'OPEN',
          url = 'https://github.com/owner/repo/pull/2',
        },
      })
      vim.system.invokes(function(_, _, callback)
        callback({ code = 0, stdout = json_response, stderr = '' })
      end)

      local result_prs
      local result_err

      api.fetch_open_prs(function(prs, err)
        result_prs = prs
        result_err = err
      end)

      flush_scheduled()

      assert.is_nil(result_err)
      assert.equals(2, #result_prs)
      assert.equals(1, result_prs[1].number)
      assert.equals('fix/bug', result_prs[1].headRefName)
    end)

    it('should handle gh command error', function()
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'gh: not logged in' })
      end)

      local result_prs
      local result_err

      api.fetch_open_prs(function(prs, err)
        result_prs = prs
        result_err = err
      end)

      flush_scheduled()

      assert.is_nil(result_prs)
      assert.is.not_nil(result_err)
      assert.matches('not logged in', result_err)
    end)
  end)

  describe('fetch_branches_with_prs', function()
    it('should return branches with PR info merged', function()
      stub(vim, 'system')

      -- First call: git branch -r
      -- Second call: gh pr list
      local call_count = 0
      vim.system.invokes(function(cmd, _, callback)
        call_count = call_count + 1
        if cmd[1] == 'git' then
          callback({
            code = 0,
            stdout = 'origin/main\norigin/feature/branch-1\norigin/feature/branch-2\n',
            stderr = '',
          })
        else
          -- gh pr list
          local json_response = vim.fn.json_encode({
            {
              number = 10,
              title = 'PR Title',
              headRefName = 'feature/branch-1',
              state = 'OPEN',
              url = 'https://github.com/owner/repo/pull/10',
            },
          })
          callback({ code = 0, stdout = json_response, stderr = '' })
        end
      end)

      local result_branches
      local result_err

      api.fetch_branches_with_prs(function(branches, err)
        result_branches = branches
        result_err = err
      end)

      flush_scheduled()
      flush_scheduled() -- Second flush for nested async

      assert.is_nil(result_err)
      assert.is.not_nil(result_branches)
      assert.equals(3, #result_branches)

      -- Check branch without PR
      local main_branch = nil
      local pr_branch = nil
      for _, b in ipairs(result_branches) do
        if b.branch == 'main' then
          main_branch = b
        end
        if b.branch == 'feature/branch-1' then
          pr_branch = b
        end
      end

      assert.is.not_nil(main_branch)
      assert.is_nil(main_branch.pr_number)

      assert.is.not_nil(pr_branch)
      assert.equals(10, pr_branch.pr_number)
      assert.equals('PR Title', pr_branch.pr_title)
    end)
  end)
end)
