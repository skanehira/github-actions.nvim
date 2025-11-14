dofile('spec/minimal_init.lua')

---@diagnostic disable: need-check-nil, param-type-mismatch, missing-parameter, redundant-parameter

describe('watch.run_picker', function()
  local run_picker

  before_each(function()
    package.loaded['github-actions.watch.run_picker'] = nil
    run_picker = require('github-actions.watch.run_picker')
  end)

  describe('format_run_entry', function()
    it('should format run with status icon, branch, and run ID', function()
      local icons = {
        in_progress = '⊙',
        queued = '○',
      }

      local run = {
        databaseId = 12345,
        status = 'in_progress',
        headBranch = 'feature/test',
        displayTitle = 'CI build',
        createdAt = '2025-11-14T10:00:00Z',
      }

      local result = run_picker.format_run_entry(run, icons)

      assert.equals('[⊙] feature/test (#12345)', result)
    end)

    it('should format queued run correctly', function()
      local icons = {
        in_progress = '⊙',
        queued = '○',
      }

      local run = {
        databaseId = 67890,
        status = 'queued',
        headBranch = 'main',
        displayTitle = 'Deploy',
        createdAt = '2025-11-14T11:00:00Z',
      }

      local result = run_picker.format_run_entry(run, icons)

      assert.equals('[○] main (#67890)', result)
    end)

    it('should use unknown icon for unrecognized status', function()
      local icons = {
        in_progress = '⊙',
        queued = '○',
        unknown = '?',
      }

      local run = {
        databaseId = 99999,
        status = 'some_weird_status',
        headBranch = 'develop',
        displayTitle = 'Test',
        createdAt = '2025-11-14T12:00:00Z',
      }

      local result = run_picker.format_run_entry(run, icons)

      assert.equals('[?] develop (#99999)', result)
    end)

    it('should handle runs with long branch names', function()
      local icons = {
        in_progress = '⊙',
      }

      local run = {
        databaseId = 11111,
        status = 'in_progress',
        headBranch = 'feature/very-long-branch-name-for-testing',
        displayTitle = 'Test',
        createdAt = '2025-11-14T13:00:00Z',
      }

      local result = run_picker.format_run_entry(run, icons)

      assert.equals('[⊙] feature/very-long-branch-name-for-testing (#11111)', result)
    end)
  end)

  describe('select_run', function()
    it('should call on_select callback with selected run', function()
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
          headBranch = 'develop',
          displayTitle = 'Build',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local icons = {
        in_progress = '⊙',
        queued = '○',
        unknown = '?',
      }

      -- Stub vim.ui.select to simulate user selection
      local original_select = vim.ui.select
      vim.ui.select = function(items, opts, on_choice)
        -- Simulate selecting the first item
        on_choice(items[1])
      end

      local callback_called = false
      local callback_run = nil

      run_picker.select_run({
        prompt = 'Select run:',
        runs = runs,
        icons = icons,
        on_select = function(run)
          callback_called = true
          callback_run = run
        end,
      })

      -- Verify callback was called with correct run
      assert.is_true(callback_called)
      assert.is_not_nil(callback_run)
      assert.equals(1, callback_run.databaseId)

      -- Cleanup
      vim.ui.select = original_select
    end)

    it('should not call callback when user cancels selection', function()
      local runs = {
        {
          databaseId = 1,
          status = 'in_progress',
          headBranch = 'main',
          displayTitle = 'CI',
          createdAt = '2025-11-14T10:00:00Z',
        },
      }

      local icons = {
        in_progress = '⊙',
      }

      local original_select = vim.ui.select
      vim.ui.select = function(items, opts, on_choice)
        -- Simulate user cancellation
        on_choice(nil)
      end

      local callback_called = false

      run_picker.select_run({
        prompt = 'Select run:',
        runs = runs,
        icons = icons,
        on_select = function(run)
          callback_called = true
        end,
      })

      -- Callback should not be called on cancellation
      assert.is_false(callback_called)

      -- Cleanup
      vim.ui.select = original_select
    end)

    it('should format all runs in the picker', function()
      local runs = {
        {
          databaseId = 100,
          status = 'in_progress',
          headBranch = 'feature-a',
          displayTitle = 'Test A',
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 200,
          status = 'queued',
          headBranch = 'feature-b',
          displayTitle = 'Test B',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local icons = {
        in_progress = '⊙',
        queued = '○',
        unknown = '?',
      }

      local original_select = vim.ui.select
      local captured_items = nil
      vim.ui.select = function(items, opts, on_choice)
        captured_items = items
        on_choice(nil)
      end

      run_picker.select_run({
        prompt = 'Select run:',
        runs = runs,
        icons = icons,
        on_select = function(run) end,
      })

      -- Verify formatted items
      assert.is_not_nil(captured_items)
      assert.equals(2, #captured_items)
      assert.equals('[⊙] feature-a (#100)', captured_items[1])
      assert.equals('[○] feature-b (#200)', captured_items[2])

      -- Cleanup
      vim.ui.select = original_select
    end)

    it('should pass correct prompt to vim.ui.select', function()
      local runs = {
        {
          databaseId = 1,
          status = 'in_progress',
          headBranch = 'main',
          displayTitle = 'CI',
          createdAt = '2025-11-14T10:00:00Z',
        },
      }

      local icons = { in_progress = '⊙' }

      local original_select = vim.ui.select
      local captured_opts = nil
      vim.ui.select = function(items, opts, on_choice)
        captured_opts = opts
        on_choice(nil)
      end

      run_picker.select_run({
        prompt = 'Test prompt:',
        runs = runs,
        icons = icons,
        on_select = function(run) end,
      })

      -- Verify prompt was passed correctly
      assert.is_not_nil(captured_opts)
      assert.equals('Test prompt:', captured_opts.prompt)

      -- Cleanup
      vim.ui.select = original_select
    end)

    it('should handle selection by formatted string index', function()
      local runs = {
        {
          databaseId = 1,
          status = 'in_progress',
          headBranch = 'first',
          displayTitle = 'First',
          createdAt = '2025-11-14T10:00:00Z',
        },
        {
          databaseId = 2,
          status = 'queued',
          headBranch = 'second',
          displayTitle = 'Second',
          createdAt = '2025-11-14T09:00:00Z',
        },
      }

      local icons = {
        in_progress = '⊙',
        queued = '○',
      }

      local original_select = vim.ui.select
      vim.ui.select = function(items, opts, on_choice)
        -- Select second item
        on_choice(items[2])
      end

      local callback_run = nil

      run_picker.select_run({
        prompt = 'Select run:',
        runs = runs,
        icons = icons,
        on_select = function(run)
          callback_run = run
        end,
      })

      -- Verify second run was selected
      assert.is_not_nil(callback_run)
      assert.equals(2, callback_run.databaseId)
      assert.equals('second', callback_run.headBranch)

      -- Cleanup
      vim.ui.select = original_select
    end)
  end)
end)
