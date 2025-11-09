-- Test for branch_picker module

---@diagnostic disable: need-check-nil, param-type-mismatch, missing-parameter, redundant-parameter

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

describe('branch_picker', function()
  local branch_picker

  before_each(function()
    -- Clear package cache to get fresh module
    package.loaded['github-actions.dispatch.branch_picker'] = nil
    branch_picker = require('github-actions.dispatch.branch_picker')
  end)

  describe('select_branch', function()
    it('should call on_select callback with selected branch', function()
      local git = require('github-actions.lib.git')
      local stub = require('luassert.stub')

      -- Stub get_remote_branches to return test branches
      stub(git, 'get_remote_branches')
      git.get_remote_branches.returns({ 'main', 'develop', 'feature/test' })

      -- Stub vim.ui.select to simulate user selection
      local original_select = vim.ui.select
      local selected_branch = nil
      vim.ui.select = function(items, opts, on_choice)
        -- Simulate selecting the first branch
        selected_branch = items[1]
        on_choice(items[1])
      end

      local callback_called = false
      local callback_branch = nil

      branch_picker.select_branch({
        prompt = 'Select branch:',
        on_select = function(branch)
          callback_called = true
          callback_branch = branch
        end,
      })

      -- Verify callback was called with correct branch
      assert.is_true(callback_called)
      assert.equals('main', callback_branch)

      -- Cleanup
      vim.ui.select = original_select
      git.get_remote_branches:revert()
    end)

    it('should handle cancellation when user selects nothing', function()
      local git = require('github-actions.lib.git')
      local stub = require('luassert.stub')

      stub(git, 'get_remote_branches')
      git.get_remote_branches.returns({ 'main', 'develop' })

      local original_select = vim.ui.select
      vim.ui.select = function(items, opts, on_choice)
        -- Simulate user cancellation
        on_choice(nil)
      end

      local callback_called = false

      branch_picker.select_branch({
        prompt = 'Select branch:',
        on_select = function(branch)
          callback_called = true
        end,
      })

      -- Callback should not be called on cancellation
      assert.is_false(callback_called)

      -- Cleanup
      vim.ui.select = original_select
      git.get_remote_branches:revert()
    end)

    it('should show error notification when no branches found', function()
      local git = require('github-actions.lib.git')
      local stub = require('luassert.stub')

      stub(git, 'get_remote_branches')
      git.get_remote_branches.returns({})

      -- Capture vim.notify calls
      local original_notify = vim.notify
      local notify_called = false
      local notify_message = nil
      local notify_level = nil
      vim.notify = function(msg, level)
        notify_called = true
        notify_message = msg
        notify_level = level
      end

      local callback_called = false

      branch_picker.select_branch({
        prompt = 'Select branch:',
        on_select = function(branch)
          callback_called = true
        end,
      })

      -- Should show error notification
      assert.is_true(notify_called)
      assert.is_not_nil(notify_message:match('No remote branches found'))
      assert.equals(vim.log.levels.ERROR, notify_level)

      -- Callback should not be called
      assert.is_false(callback_called)

      -- Cleanup
      vim.notify = original_notify
      git.get_remote_branches:revert()
    end)

    it('should pass correct prompt to vim.ui.select', function()
      local git = require('github-actions.lib.git')
      local stub = require('luassert.stub')

      stub(git, 'get_remote_branches')
      git.get_remote_branches.returns({ 'main' })

      local original_select = vim.ui.select
      local captured_opts = nil
      vim.ui.select = function(items, opts, on_choice)
        captured_opts = opts
        on_choice(items[1])
      end

      branch_picker.select_branch({
        prompt = 'Test prompt:',
        on_select = function(branch) end,
      })

      -- Verify prompt was passed correctly
      assert.is_not_nil(captured_opts)
      assert.equals('Test prompt:', captured_opts.prompt)

      -- Cleanup
      vim.ui.select = original_select
      git.get_remote_branches:revert()
    end)
  end)
end)
