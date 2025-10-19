dofile('spec/minimal_init.lua')

local buffer_helper = require('spec.helpers.buffer_spec')

describe('workflow.detector', function()
  local detector = require('github-actions.workflow.detector')

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
end)
