-- Test for git module

---@diagnostic disable: need-check-nil, param-type-mismatch, missing-parameter, redundant-parameter

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

describe('git', function()
  local git = require('github-actions.lib.git')

  describe('parse_branches', function()
    it('should parse local branches only', function()
      local stdout = [[
main
develop
feature/test
]]
      local branches = git.parse_branches(stdout)

      assert.equals(3, #branches)
      assert.same({ 'main', 'develop', 'feature/test' }, branches)
    end)

    it('should exclude remote tracking branches', function()
      local stdout = [[
main
origin/main
origin/develop
develop
]]
      local branches = git.parse_branches(stdout)

      assert.equals(2, #branches)
      assert.same({ 'main', 'develop' }, branches)
    end)

    it('should exclude remote name itself (origin)', function()
      local stdout = [[
main
origin
origin/main
]]
      local branches = git.parse_branches(stdout)

      assert.equals(1, #branches)
      assert.same({ 'main' }, branches)
    end)

    it('should handle empty output', function()
      local stdout = ''
      local branches = git.parse_branches(stdout)

      assert.equals(0, #branches)
    end)

    it('should remove duplicates', function()
      local stdout = [[
main
main
develop
]]
      local branches = git.parse_branches(stdout)

      assert.equals(2, #branches)
      assert.same({ 'main', 'develop' }, branches)
    end)

    it('should trim whitespace', function()
      local stdout = [[
  main
  develop
]]
      local branches = git.parse_branches(stdout)

      assert.equals(2, #branches)
      assert.same({ 'main', 'develop' }, branches)
    end)
  end)

  describe('sort_branches_by_default', function()
    it('should move default branch to first position', function()
      local branches = { 'develop', 'main', 'feature/test' }
      local result = git.sort_branches_by_default(branches, 'main')

      assert.equals(3, #result)
      assert.equals('main', result[1])
    end)

    it('should handle default branch not in list', function()
      local branches = { 'develop', 'feature/test' }
      local result = git.sort_branches_by_default(branches, 'main')

      assert.equals(2, #result)
      assert.equals('develop', result[1])
    end)

    it('should handle empty branches list', function()
      local branches = {}
      local result = git.sort_branches_by_default(branches, 'main')

      assert.equals(0, #result)
    end)
  end)

  describe('get_branches', function()
    it('should return branches with default first', function()
      local stub = require('luassert.stub')

      local call_count = 0
      stub(git, 'execute_git_command')
      git.execute_git_command.invokes(function(_)
        call_count = call_count + 1
        if call_count == 1 then
          -- First call: get branches
          return [[
develop
main
feature/test
origin/main
origin/develop
]], 0
        else
          -- Second call: get default branch
          return 'refs/remotes/origin/main\n', 0
        end
      end)

      local branches = git.get_branches()

      assert.equals(3, #branches)
      assert.equals('main', branches[1]) -- Default branch should be first
      assert.is_true(vim.tbl_contains(branches, 'develop'))
      assert.is_true(vim.tbl_contains(branches, 'feature/test'))

      assert.stub(git.execute_git_command).was_called(2)
    end)

    it('should handle git command failure', function()
      local stub = require('luassert.stub')

      stub(git, 'execute_git_command')
      git.execute_git_command.returns('', 1)

      local branches = git.get_branches()

      assert.equals(0, #branches)

      assert.stub(git.execute_git_command).was_called()
    end)

    it('should fallback to main when default branch not found', function()
      local stub = require('luassert.stub')

      local call_count = 0
      stub(git, 'execute_git_command')
      git.execute_git_command.invokes(function(_)
        call_count = call_count + 1
        if call_count == 1 then
          return [[
develop
feature/test
]], 0
        else
          return '', 1 -- Failed to get default branch
        end
      end)

      local branches = git.get_branches()

      assert.equals(2, #branches)

      assert.stub(git.execute_git_command).was_called(2)
    end)
  end)
end)
