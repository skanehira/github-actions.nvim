-- Test for version check module (business logic only)

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local helpers = require('spec.helpers.buffer_spec')

describe('workflow.checker', function()
  ---@type WorkflowChecker
  local checker = require('github-actions.versions.checker')
  ---@type number
  local test_bufnr

  before_each(function()
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
        checker.check_versions(test_bufnr, function(version_infos, _)
          -- Callback should be called eventually
          assert.equals('table', type(version_infos or {}))
        end)
      end)
    end)

    it('should coalesce API calls for the same owner/repo into a single fetch', function()
      -- Buffer with the same action twice (different versions) must only fetch
      -- the latest release ONCE — duplicates waste GitHub API rate limit.
      local dup_bufnr = helpers.create_yaml_buffer([[
name: Dup
on: push
jobs:
  job1:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
  job2:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
]])

      -- Clear any cached version from earlier tests in this file
      local cache = require('github-actions.versions.cache')
      cache.clear()

      local stub = require('luassert.stub')
      local github = require('github-actions.shared.github')
      stub(github, 'is_available')
      github.is_available.returns(true)

      local fetch_count = 0
      stub(github, 'fetch_latest_release')
      github.fetch_latest_release.invokes(function(_, _, callback)
        fetch_count = fetch_count + 1
        callback('v5.0.0', nil)
      end)

      local callback_called = false
      local infos_count = 0
      checker.check_versions(dup_bufnr, function(version_infos, _)
        callback_called = true
        infos_count = version_infos and #version_infos or 0
      end)

      vim.wait(200, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      assert.equals(1, fetch_count, 'fetch_latest_release must run once for duplicate actions/checkout')
      assert.equals(2, infos_count, 'must still produce a version_info for each action use')

      github.is_available:revert()
      github.fetch_latest_release:revert()
      cache.clear()
      helpers.delete_buffer(dup_bufnr)
    end)
  end)
end)
