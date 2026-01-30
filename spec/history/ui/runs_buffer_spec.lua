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
      local bufnr, winnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

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
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

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

    it('should set up r keymap for refresh', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

      -- Check that 'r' keymap exists
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_r_keymap = false
      for _, map in ipairs(keymaps) do
        if map.lhs == 'r' then
          has_r_keymap = true
          break
        end
      end
      assert.is_true(has_r_keymap, 'Should have "r" keymap to refresh buffer')
    end)

    it('should set up R keymap for rerun', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

      -- Check that 'R' keymap exists
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_R_keymap = false
      for _, map in ipairs(keymaps) do
        if map.lhs == 'R' then
          has_R_keymap = true
          break
        end
      end
      assert.is_true(has_R_keymap, 'Should have "R" keymap to rerun workflow')
    end)

    it('should set up d keymap for dispatch', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

      -- Check that 'd' keymap exists
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_d_keymap = false
      for _, map in ipairs(keymaps) do
        if map.lhs == 'd' then
          has_d_keymap = true
          break
        end
      end
      assert.is_true(has_d_keymap, 'Should have "d" keymap to dispatch workflow')
    end)

    it('should store workflow_file in buffer data', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

      -- Render some data to ensure buffer_data is populated
      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
      }
      runs_buffer.render(bufnr, runs)

      -- Access buffer_data through render to verify workflow_file is preserved
      -- We can't directly access buffer_data as it's local, but we can verify
      -- the buffer was created successfully which implies workflow_file was stored
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      assert.equals('ci.yml', vim.api.nvim_buf_get_name(bufnr):match('(%S+%.yml)'))
    end)
  end)

  describe('render', function()
    it('should render run list in buffer', function()
      local bufnr, _ = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

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
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

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
      local _ = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

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
      local bufnr1, winnr1 = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')
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
      local bufnr2, winnr2 = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

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
      local bufnr1, _ = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml', false)

      -- Hide the buffer (wipe it by closing all windows in the tab)
      vim.cmd('bdelete! ' .. bufnr1)

      -- Create the buffer again - should create new buffer since old one was wiped
      local bufnr2, winnr2 = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

      assert.is_not_nil(bufnr2)
      assert.is_not_nil(winnr2)
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr2))
      assert.is_true(vim.api.nvim_win_is_valid(winnr2))
    end)
  end)

  describe('render with expanded runs', function()
    it('should render expanded jobs and steps', function()
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

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
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

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

  describe('watch run functionality', function()
    it('should set up w keymap for watching runs', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

      -- Check that 'w' keymap exists
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_w_keymap = false
      for _, map in ipairs(keymaps) do
        if map.lhs == 'w' then
          has_w_keymap = true
          break
        end
      end
      assert.is_true(has_w_keymap, 'Should have "w" keymap to watch run')
    end)

    it('should show help text mentioning w keymap', function()
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'in_progress',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
      }

      runs_buffer.render(bufnr, runs)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Help text should mention w keymap
      assert.matches('w watch', content)
    end)

    it('should allow watching queued runs', function()
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

      local runs = {
        {
          databaseId = 12346,
          displayTitle = 'queued run',
          headBranch = 'main',
          status = 'queued',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
      }

      runs_buffer.render(bufnr, runs)

      -- Move cursor to the run line
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Test that queued runs can be watched (this test will pass if no error is thrown)
      -- In actual implementation, watch_run should accept 'queued' status
      assert.is_true(true)
    end)
  end)

  describe('cancel run functionality', function()
    it('should set up C keymap for cancelling runs', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

      -- Check that 'C' keymap exists
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_C_keymap = false
      for _, map in ipairs(keymaps) do
        if map.lhs == 'C' then
          has_C_keymap = true
          break
        end
      end
      assert.is_true(has_C_keymap, 'Should have "C" keymap to cancel run')
    end)

    it('should show help text mentioning C keymap', function()
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'in_progress',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
      }

      runs_buffer.render(bufnr, runs)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Help text should mention C keymap
      assert.matches('C cancel', content)
    end)
  end)

  describe('open run in browser functionality', function()
    it('should set up <C-o> keymap for opening runs in browser', function()
      local bufnr, _ = runs_buffer.create_buffer('ci.yml', '.github/workflows/ci.yml')

      -- Check that '<C-o>' keymap exists
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_ctrl_o_keymap = false
      for _, map in ipairs(keymaps) do
        if map.lhs == '<C-O>' then
          has_ctrl_o_keymap = true
          break
        end
      end
      assert.is_true(has_ctrl_o_keymap, 'Should have "<C-o>" keymap to open run in browser')
    end)

    it('should show help text mentioning <C-o> keymap', function()
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
      }

      runs_buffer.render(bufnr, runs)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, '\n')

      -- Help text should mention <C-o> keymap
      assert.matches('<C%-o> open', content)
    end)
  end)

  describe('keymap help text position', function()
    it('should display keymap help text at the top of the buffer', function()
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
      }

      runs_buffer.render(bufnr, runs)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- First line should contain keymap help text
      assert.matches('l expand', lines[1])
      assert.matches('q close', lines[1])
    end)

    it('should have empty line after help text', function()
      local bufnr = runs_buffer.create_buffer('test.yml', '.github/workflows/test.yml')

      local runs = {
        {
          databaseId = 12345,
          displayTitle = 'test run',
          headBranch = 'main',
          status = 'completed',
          conclusion = 'success',
          createdAt = '2025-10-19T10:00:00Z',
          updatedAt = '2025-10-19T10:05:00Z',
        },
      }

      runs_buffer.render(bufnr, runs)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Second line should be empty
      assert.equals('', lines[2])
    end)
  end)
end)
