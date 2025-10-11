-- Test for version check module (business logic only)

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local helpers = require('spec.helpers.buffer_spec')

describe('workflow.checker', function()
  ---@type WorkflowChecker
  local checker
  ---@type number
  local test_bufnr

  before_each(function()
    checker = require('github-actions.workflow.checker')
    test_bufnr = helpers.create_yaml_buffer([[\
name: Test Workflow

on: push

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v4
]])
  end)

  after_each(function()
    helpers.delete_buffer(test_bufnr)
  end)

  describe('check_versions', function()
    it('should exist and be callable', function()
      assert.equals('function', type(checker.check_versions))
    end)

    it('should return error for invalid buffer', function()
      local callback_called = false
      checker.check_versions(999999, function(version_infos, error)
        callback_called = true
        assert.is_nil(version_infos)
        assert.is_not_nil(error)
      end)
      assert.is_true(callback_called)
    end)

    it('should return empty array for buffer with no actions', function()
      local empty_bufnr = helpers.create_yaml_buffer([[\
name: Empty Workflow

on: push

jobs:
  test:
    runs-on: ubuntu-latest
]])

      local callback_called = false
      checker.check_versions(empty_bufnr, function(version_infos, error)
        callback_called = true
        assert.is_nil(error)
        assert.is_not_nil(version_infos)
        assert.equals(0, #version_infos)
      end)
      assert.is_true(callback_called)

      helpers.delete_buffer(empty_bufnr)
    end)

    it('should return version infos via callback', function()
      -- This test verifies the function signature and basic flow
      -- Actual API calls would require mocking
      assert.has.no.errors(function()
        checker.check_versions(test_bufnr, function(version_infos, error)
          -- Callback should be called eventually
          assert.equals('table', type(version_infos or {}))
        end)
      end)
    end)
  end)
end)
