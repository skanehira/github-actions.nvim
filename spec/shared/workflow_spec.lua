dofile('spec/minimal_init.lua')

local buffer_helper = require('spec.helpers.buffer_spec')

describe('workflow.detector', function()
  local detector = require('github-actions.shared.workflow')

  describe('is_workflow_file', function()
    local test_cases = {
      {
        name = 'should return true for .github/workflows/*.yml files',
        path = '/path/to/project/.github/workflows/ci.yml',
        expected = true,
      },
      {
        name = 'should return true for .github/workflows/*.yaml files',
        path = '/path/to/project/.github/workflows/test.yaml',
        expected = true,
      },
      {
        name = 'should return false for non-workflow files',
        path = '/path/to/project/README.md',
        expected = false,
      },
      {
        name = 'should return false for .github/actions/*/action.yml files',
        path = '/path/to/project/.github/actions/test/action.yml',
        expected = false,
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        assert.are.equal(tc.expected, detector.is_workflow_file(tc.path))
      end)
    end
  end)

  describe('get_workflow_name', function()
    local test_cases = {
      {
        name = 'should extract workflow name from YAML content',
        content = 'name: CI\n\non: [push]',
        expected = 'CI',
      },
      {
        name = 'should handle names with spaces',
        content = 'name: Test Workflow\n\non: [push]',
        expected = 'Test Workflow',
      },
      {
        name = 'should handle quoted names and remove quotes',
        content = "name: 'CI Pipeline'\n\non: [push]",
        expected = 'CI Pipeline',
      },
      {
        name = 'should handle double quoted names and remove quotes',
        content = 'name: "Deploy Production"\n\non: [push]',
        expected = 'Deploy Production',
      },
      {
        name = 'should return nil for workflow without name field',
        content = 'on: [push]\n\njobs:',
        expected = nil,
      },
      {
        name = 'should ignore comments',
        content = '# This is a comment\nname: CI\n\non: [push]',
        expected = 'CI',
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        local buf = buffer_helper.create_yaml_buffer(tc.content)
        local name = detector.get_workflow_name(buf)

        if tc.expected == nil then
          assert.is_nil(name)
        else
          assert.equals(tc.expected, name)
        end

        buffer_helper.delete_buffer(buf)
      end)
    end
  end)

  describe('find_workflows_dir_upwards', function()
    it('should return workflows dir when it exists in start_dir', function()
      local start_dir = '/tmp/test_project'
      local workflows_dir = start_dir .. '/.github/workflows'

      -- Mock vim.fn.isdirectory to simulate existing directory
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        if path == workflows_dir then
          return 1
        end
        return 0
      end

      local result = detector.find_workflows_dir_upwards(start_dir)
      assert.equals(workflows_dir, result)

      -- Restore original function
      vim.fn.isdirectory = original_isdirectory
    end)

    it('should return workflows dir when it exists in parent directory', function()
      local parent_dir = '/tmp/test_project'
      local start_dir = parent_dir .. '/subdir'
      local workflows_dir = parent_dir .. '/.github/workflows'

      -- Mock vim.fn.isdirectory
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        if path == workflows_dir then
          return 1
        end
        return 0
      end

      local result = detector.find_workflows_dir_upwards(start_dir)
      assert.equals(workflows_dir, result)

      vim.fn.isdirectory = original_isdirectory
    end)

    it('should return nil when workflows dir not found up to home directory', function()
      local start_dir = '/tmp/test_project'

      -- Mock vim.fn.isdirectory to always return 0
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        return 0
      end

      -- Mock vim.fn.expand to return a fake home directory
      local original_expand = vim.fn.expand
      vim.fn.expand = function(path)
        if path == '~' then
          return '/home/testuser'
        end
        return original_expand(path)
      end

      local result = detector.find_workflows_dir_upwards(start_dir)
      assert.is_nil(result)

      vim.fn.isdirectory = original_isdirectory
      vim.fn.expand = original_expand
    end)

    it('should stop searching at home directory', function()
      local home_dir = vim.fn.expand('~')
      local start_dir = home_dir .. '/projects/test'

      -- Mock vim.fn.isdirectory to track which paths were checked
      local checked_paths = {}
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        table.insert(checked_paths, path)
        return 0
      end

      local result = detector.find_workflows_dir_upwards(start_dir)
      assert.is_nil(result)

      -- Verify that we didn't search beyond home directory
      for _, path in ipairs(checked_paths) do
        assert.is_true(path:find(home_dir, 1, true) == 1, 'Should not search beyond home directory: ' .. path)
      end

      vim.fn.isdirectory = original_isdirectory
    end)
  end)

  describe('find_workflow_files', function()
    local git = require('github-actions.lib.git')

    it('should use git root when in a git repository', function()
      local git_root = '/path/to/repo'
      local workflows_dir = git_root .. '/.github/workflows'

      -- Mock git.get_git_root
      local original_get_git_root = git.get_git_root
      git.get_git_root = function()
        return git_root
      end

      -- Mock vim.fn.isdirectory
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        if path == workflows_dir then
          return 1
        end
        return 0
      end

      -- Mock vim.fn.glob to return workflow files
      local original_glob = vim.fn.glob
      vim.fn.glob = function(pattern, _, _)
        if pattern == workflows_dir .. '/*.yml' then
          return { workflows_dir .. '/ci.yml', workflows_dir .. '/deploy.yml' }
        elseif pattern == workflows_dir .. '/*.yaml' then
          return {}
        end
        return {}
      end

      -- Mock vim.pesc
      local original_pesc = vim.pesc
      vim.pesc = function(str)
        return str:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
      end

      local result = detector.find_workflow_files()
      assert.equals(2, #result)

      -- Restore original functions
      git.get_git_root = original_get_git_root
      vim.fn.isdirectory = original_isdirectory
      vim.fn.glob = original_glob
      vim.pesc = original_pesc
    end)

    it('should search upwards when not in a git repository', function()
      local cwd = '/path/to/project/subdir'
      local parent_dir = '/path/to/project'
      local workflows_dir = parent_dir .. '/.github/workflows'

      -- Mock git.get_git_root to return nil
      local original_get_git_root = git.get_git_root
      git.get_git_root = function()
        return nil
      end

      -- Mock vim.fn.getcwd
      local original_getcwd = vim.fn.getcwd
      vim.fn.getcwd = function()
        return cwd
      end

      -- Mock vim.fn.isdirectory
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        if path == workflows_dir then
          return 1
        end
        return 0
      end

      -- Mock vim.fn.glob
      local original_glob = vim.fn.glob
      vim.fn.glob = function(pattern, _, _)
        if pattern == workflows_dir .. '/*.yml' then
          return { workflows_dir .. '/test.yml' }
        elseif pattern == workflows_dir .. '/*.yaml' then
          return {}
        end
        return {}
      end

      -- Mock vim.pesc
      local original_pesc = vim.pesc
      vim.pesc = function(str)
        return str:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
      end

      local result = detector.find_workflow_files()
      assert.equals(1, #result)

      -- Restore
      git.get_git_root = original_get_git_root
      vim.fn.getcwd = original_getcwd
      vim.fn.isdirectory = original_isdirectory
      vim.fn.glob = original_glob
      vim.pesc = original_pesc
    end)

    it('should return empty list when workflows dir not found', function()
      -- Mock git.get_git_root to return nil
      local original_get_git_root = git.get_git_root
      git.get_git_root = function()
        return nil
      end

      -- Mock vim.fn.getcwd
      local original_getcwd = vim.fn.getcwd
      vim.fn.getcwd = function()
        return '/tmp/test'
      end

      -- Mock vim.fn.isdirectory to always return 0
      local original_isdirectory = vim.fn.isdirectory
      vim.fn.isdirectory = function(path)
        return 0
      end

      -- Mock vim.fn.expand
      local original_expand = vim.fn.expand
      vim.fn.expand = function(path)
        if path == '~' then
          return '/home/testuser'
        end
        return original_expand(path)
      end

      local result = detector.find_workflow_files()
      assert.equals(0, #result)

      -- Restore
      git.get_git_root = original_get_git_root
      vim.fn.getcwd = original_getcwd
      vim.fn.isdirectory = original_isdirectory
      vim.fn.expand = original_expand
    end)
  end)
end)
