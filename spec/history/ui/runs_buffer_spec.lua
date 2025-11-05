dofile('spec/minimal_init.lua')

describe('history.ui.runs_buffer', function()
  local runs_buffer = require('github-actions.history.ui.runs_buffer')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == 'nofile' then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('create_buffer', function()
    it('should create a buffer with correct options', function()
      local bufnr, winnr = runs_buffer.create_buffer('test.yml')

      assert.is.not_nil(bufnr)
      assert.is.not_nil(winnr)
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      assert.is_true(vim.api.nvim_win_is_valid(winnr))

      -- Check buffer options
      assert.equals('nofile', vim.bo[bufnr].buftype)
      assert.is_false(vim.bo[bufnr].modifiable)
      assert.is_false(vim.bo[bufnr].swapfile)

      -- Check buffer name
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      assert.matches('GitHub Actions.*test%.yml', bufname)
    end)

    it('should set up keymaps', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml')

      -- Check that 'q' keymap exists
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_q_keymap = false
      for _, map in ipairs(keymaps) do
        if map.lhs == 'q' then
          has_q_keymap = true
          break
        end
      end
      assert.is_true(has_q_keymap, 'Should have "q" keymap to close buffer')
    end)
  end)

  describe('render', function()
    it('should render run list in buffer', function()
      local bufnr, _ = runs_buffer.create_buffer('test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'feat: add feature',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
        {
          databaseId = 12346,
          displayTitle = 'fix: bug fix',
          headBranch = 'fix/bug',
          status = 'completed',
          conclusion = 'failure',
          createdAt = '2025-10-19T09:00:00Z',
          updatedAt = '2025-10-19T09:02:00Z',
        },
      }

      runs_buffer.render(bufnr, runs)

      -- Get buffer lines
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Should have 2 runs + footer
      assert.is_true(#lines >= 2, 'Should have at least 2 runs')

      -- Check that runs are rendered
      local content = table.concat(lines, '\n')
      assert.matches('#12345', content)
      assert.matches('feat: add feature', content)
      assert.matches('#12346', content)
      assert.matches('fix: bug fix', content)
    end)

    it('should handle empty run list', function()
      local bufnr = runs_buffer.create_buffer('test.yml')

      runs_buffer.render(bufnr, {})

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Should have empty message + footer
      assert.is_true(#lines >= 1)
      local content = table.concat(lines, '\n')
      assert.matches('No workflow runs found', content)
    end)
  end)

  describe('expand/collapse state management', function()
    it('should track expanded state for runs', function()
      local _ = runs_buffer.create_buffer('test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
          expanded = false,
        },
      }

      -- Initially not expanded
      assert.is_false(runs[1].expanded)

      -- Toggle expand
      runs[1].expanded = true
      assert.is_true(runs[1].expanded)

      -- Toggle collapse
      runs[1].expanded = false
      assert.is_false(runs[1].expanded)
    end)

    it('should store jobs data when expanded', function()
      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
          expanded = false,
          jobs = nil,
        },
      }

      -- Add jobs when expanding
      runs[1].jobs = {
        {
          name = 'test',
          status = 'completed',
          conclusion = 'success',
          startedAt = '2025-10-19T10:00:00Z',
          completedAt = '2025-10-19T10:03:00Z',
          steps = {},
        },
      }
      runs[1].expanded = true

      assert.is_not_nil(runs[1].jobs)
      assert.equals(1, #runs[1].jobs)
      assert.equals('test', runs[1].jobs[1].name)
    end)
  end)

  describe('buffer reuse behavior', function()
    it('should not switch windows when buffer is already displayed', function()
      -- Create initial buffer in first tab
      local bufnr1, winnr1 = runs_buffer.create_buffer('test.yml')
      assert.is_not_nil(bufnr1)
      assert.is_not_nil(winnr1)
      local initial_tab = vim.api.nvim_get_current_tabpage()

      -- Create a new tab and switch to it
      vim.cmd('tabnew')
      local new_tab = vim.api.nvim_get_current_tabpage()
      local new_winnr = vim.api.nvim_get_current_win()

      -- Verify we're in a different tab
      assert.is_not.equals(initial_tab, new_tab)

      -- Call create_buffer again from the new tab
      -- This should NOT switch back to the first tab/window
      local bufnr2, winnr2 = runs_buffer.create_buffer('test.yml')

      -- Should return the same buffer
      assert.equals(bufnr1, bufnr2)

      -- winnr2 should be the window in the first tab where the buffer is displayed
      assert.is_not_nil(winnr2)

      -- Most important: Current tab and window should remain unchanged
      local current_tab = vim.api.nvim_get_current_tabpage()
      local current_winnr = vim.api.nvim_get_current_win()
      assert.equals(new_tab, current_tab, 'Should still be in the new tab')
      assert.equals(new_winnr, current_winnr, 'Should still be in the new window')

      -- Verify that the buffer is indeed displayed in winnr2
      local buf_in_win = vim.api.nvim_win_get_buf(winnr2)
      assert.equals(bufnr1, buf_in_win)
    end)

    it('should create new window when buffer exists but not displayed', function()
      -- Create buffer
      local bufnr1, _ = runs_buffer.create_buffer('test.yml', false)

      -- Hide the buffer (wipe it by closing all windows in the tab)
      vim.cmd('bdelete! ' .. bufnr1)

      -- Create the buffer again - should create new buffer since old one was wiped
      local bufnr2, winnr2 = runs_buffer.create_buffer('test.yml')

      assert.is_not_nil(bufnr2)
      assert.is_not_nil(winnr2)
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr2))
      assert.is_true(vim.api.nvim_win_is_valid(winnr2))
    end)
  end)

  describe('render with expanded runs', function()
    it('should render expanded jobs and steps', function()
      local bufnr = runs_buffer.create_buffer('test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'failure',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
          expanded = true,
          jobs = {
            {
              name = 'build',
              status = 'completed',
              conclusion = 'failure',
              startedAt = '2025-10-19T10:00:00Z',
              completedAt = '2025-10-19T10:03:00Z',
              steps = {
                {
                  name = 'Setup',
                  status = 'completed',
                  conclusion = 'success',
                  startedAt = '2025-10-19T10:00:00Z',
                  completedAt = '2025-10-19T10:00:10Z',
                },
                {
                  name = 'Build',
                  status = 'completed',
                  conclusion = 'failure',
                  startedAt = '2025-10-19T10:00:10Z',
                  completedAt = '2025-10-19T10:03:00Z',
                },
              },
            },
          },
        },
      }

      runs_buffer.render(bufnr, runs)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Should contain run
      assert.matches('#12345', content)
      assert.matches('test run', content)

      -- Should contain expanded job
      assert.matches('Job: build', content)

      -- Should contain steps with tree prefixes
      assert.matches('├─.*Setup', content)
      assert.matches('└─.*Build', content)
    end)

    it('should not render jobs when not expanded', function()
      local bufnr = runs_buffer.create_buffer('test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
          expanded = false,
          jobs = {
            {
              name = 'build',
              status = 'completed',
              conclusion = 'success',
            },
          },
        },
      }

      runs_buffer.render(bufnr, runs)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Should contain run
      assert.matches('#12345', content)

      -- Should NOT contain job when not expanded
      assert.not_matches('Job: build', content)
    end)
  end)
end)
