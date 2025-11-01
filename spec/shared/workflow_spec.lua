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
    local fs_helper = require('spec.helpers.filesystem')
    local temp_dir

    after_each(function()
      if temp_dir then
        fs_helper.cleanup(temp_dir)
        temp_dir = nil
      end
    end)

    it('should return workflows dir when it exists in start_dir', function()
      temp_dir = fs_helper.create_temp_project({
        has_workflows_dir = true,
      })

      local result = detector.find_workflows_dir_upwards(temp_dir)
      assert.equals(temp_dir .. '/.github/workflows', result)
    end)

    it('should return workflows dir when it exists in parent directory', function()
      temp_dir = fs_helper.create_temp_project({
        has_workflows_dir = true,
        subdirs = { 'subdir' },
      })

      local start_dir = temp_dir .. '/subdir'
      local result = detector.find_workflows_dir_upwards(start_dir)
      assert.equals(temp_dir .. '/.github/workflows', result)
    end)

    it('should return nil when workflows dir not found up to home directory', function()
      temp_dir = fs_helper.create_temp_project({
        has_workflows_dir = false,
      })

      -- Mock vim.fn.expand to set temp_dir as home boundary
      local original_expand = vim.fn.expand
      vim.fn.expand = function(path)
        if path == '~' then
          return temp_dir
        end
        return original_expand(path)
      end

      local result = detector.find_workflows_dir_upwards(temp_dir)
      assert.is_nil(result)

      vim.fn.expand = original_expand
    end)

    it('should stop searching at home directory', function()
      temp_dir = fs_helper.create_temp_project({
        has_workflows_dir = false,
        subdirs = { 'projects/test' },
      })

      -- Mock vim.fn.expand to set temp_dir as home boundary
      local original_expand = vim.fn.expand
      vim.fn.expand = function(path)
        if path == '~' then
          return temp_dir
        end
        return original_expand(path)
      end

      local start_dir = temp_dir .. '/projects/test'
      local result = detector.find_workflows_dir_upwards(start_dir)
      assert.is_nil(result)

      vim.fn.expand = original_expand
    end)
  end)

  describe('find_workflow_files', function()
    local fs_helper = require('spec.helpers.filesystem')
    local temp_dir

    after_each(function()
      if temp_dir then
        fs_helper.cleanup(temp_dir)
        temp_dir = nil
      end
    end)

    it('should use git root when in a git repository', function()
      temp_dir = fs_helper.create_temp_project({
        has_workflows_dir = true,
        workflow_files = { 'ci.yml', 'deploy.yml' },
        is_git_repo = true,
      })

      -- Change to temp directory to simulate being in git repo
      local original_getcwd = vim.fn.getcwd
      vim.fn.getcwd = function()
        return temp_dir
      end

      local result = detector.find_workflow_files()
      assert.equals(2, #result)

      -- Verify file paths
      local has_ci = false
      local has_deploy = false
      for _, file in ipairs(result) do
        if file:match('ci%.yml$') then
          has_ci = true
        elseif file:match('deploy%.yml$') then
          has_deploy = true
        end
      end
      assert.is_true(has_ci, 'Should find ci.yml')
      assert.is_true(has_deploy, 'Should find deploy.yml')

      vim.fn.getcwd = original_getcwd
    end)

    it('should search upwards when not in a git repository', function()
      temp_dir = fs_helper.create_temp_project({
        has_workflows_dir = true,
        workflow_files = { 'test.yml' },
        subdirs = { 'subdir' },
        is_git_repo = false,
      })

      local subdir = temp_dir .. '/subdir'

      -- Mock getcwd to return subdirectory
      local original_getcwd = vim.fn.getcwd
      vim.fn.getcwd = function()
        return subdir
      end

      local result = detector.find_workflow_files()
      assert.equals(1, #result)
      assert.is_true(result[1]:match('test%.yml$') ~= nil, 'Should find test.yml')

      vim.fn.getcwd = original_getcwd
    end)

    it('should return empty list when workflows dir not found', function()
      temp_dir = fs_helper.create_temp_project({
        has_workflows_dir = false,
        is_git_repo = false,
      })

      -- Mock getcwd and expand to control search boundaries
      local original_getcwd = vim.fn.getcwd
      vim.fn.getcwd = function()
        return temp_dir
      end

      local original_expand = vim.fn.expand
      vim.fn.expand = function(path)
        if path == '~' then
          return temp_dir
        end
        return original_expand(path)
      end

      local result = detector.find_workflow_files()
      assert.equals(0, #result)

      vim.fn.getcwd = original_getcwd
      vim.fn.expand = original_expand
    end)
  end)
end)
