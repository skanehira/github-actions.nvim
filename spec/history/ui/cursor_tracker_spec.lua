dofile('spec/minimal_init.lua')

describe('history.ui.cursor_tracker', function()
  local cursor_tracker = require('github-actions.history.ui.cursor_tracker')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('get_run_at_cursor', function()
    it('should return run index when cursor is on a run line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)

      local runs = {
        { expanded = false },
        { expanded = false },
      }

      -- Set buffer content to match expected format with header
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<CR> expand/view logs, <BS> collapse, r refresh, R rerun, D dispatch, W watch, q close',
        '',
        '✓ #12345 main: feat  2h ago  5m',
        '✓ #12346 dev: fix  1h ago  3m',
      })

      -- Move cursor to first run (line 3)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      local run_idx = cursor_tracker.get_run_at_cursor(bufnr, runs)
      assert.equals(1, run_idx)

      -- Move cursor to second run (line 4)
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      run_idx = cursor_tracker.get_run_at_cursor(bufnr, runs)
      assert.equals(2, run_idx)
    end)

    it('should handle expanded runs with jobs and steps', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)

      local runs = {
        {
          expanded = true,
          jobs = {
            { name = 'job1', steps = { {}, {} } }, -- 2 steps
          },
        },
        { expanded = false },
      }

      -- Set buffer content with header: header (line 1), empty (line 2), run1 (line 3), job (line 4), step1 (line 5), step2 (line 6), run2 (line 7)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<CR> expand/view logs, <BS> collapse, r refresh, R rerun, D dispatch, W watch, q close',
        '',
        '✓ #12345 main: feat',
        '  ✓ Job: job1',
        '    ├─ ✓ step1',
        '    └─ ✓ step2',
        '✓ #12346 dev: fix',
      })

      -- Cursor on first run (line 3)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      local run_idx = cursor_tracker.get_run_at_cursor(bufnr, runs)
      assert.equals(1, run_idx)

      -- Cursor on job line (should not return run index) (line 4)
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      run_idx = cursor_tracker.get_run_at_cursor(bufnr, runs)
      assert.is_nil(run_idx)

      -- Cursor on second run (line 7)
      vim.api.nvim_win_set_cursor(0, { 7, 0 })
      run_idx = cursor_tracker.get_run_at_cursor(bufnr, runs)
      assert.equals(2, run_idx)
    end)

    it('should return nil when runs is empty', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)

      local runs = {}
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'No runs' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local run_idx = cursor_tracker.get_run_at_cursor(bufnr, runs)
      assert.is_nil(run_idx)
    end)
  end)

  describe('get_job_at_cursor', function()
    it('should return run_idx and job_idx when cursor is on a job line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)

      local runs = {
        {
          expanded = true,
          jobs = {
            { name = 'job1', steps = {} },
            { name = 'job2', steps = {} },
          },
        },
      }

      -- Set buffer content with header
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<CR> expand/view logs, <BS> collapse, r refresh, R rerun, D dispatch, W watch, q close',
        '',
        '✓ #12345 main: feat',
        '  ✓ Job: job1',
        '  ✓ Job: job2',
      })

      -- Cursor on first job (line 4)
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      local run_idx, job_idx = cursor_tracker.get_job_at_cursor(runs)
      assert.equals(1, run_idx)
      assert.equals(1, job_idx)

      -- Cursor on second job (line 5)
      vim.api.nvim_win_set_cursor(0, { 5, 0 })
      run_idx, job_idx = cursor_tracker.get_job_at_cursor(runs)
      assert.equals(1, run_idx)
      assert.equals(2, job_idx)
    end)

    it('should return nil when cursor is on a run line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)

      local runs = {
        {
          expanded = true,
          jobs = {
            { name = 'job1', steps = {} },
          },
        },
      }

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<CR> expand/view logs, <BS> collapse, r refresh, R rerun, D dispatch, W watch, q close',
        '',
        '✓ #12345 main: feat',
        '  ✓ Job: job1',
      })

      -- Cursor on run line (line 3)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      local run_idx, job_idx = cursor_tracker.get_job_at_cursor(runs)
      assert.is_nil(run_idx)
      assert.is_nil(job_idx)
    end)

    it('should handle jobs with steps', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)

      local runs = {
        {
          expanded = true,
          jobs = {
            { name = 'job1', steps = { {}, {} } }, -- 2 steps
            { name = 'job2', steps = {} },
          },
        },
      }

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<CR> expand/view logs, <BS> collapse, r refresh, R rerun, D dispatch, W watch, q close',
        '',
        '✓ #12345 main: feat',
        '  ✓ Job: job1',
        '    ├─ ✓ step1',
        '    └─ ✓ step2',
        '  ✓ Job: job2',
      })

      -- Cursor on second job (should skip over job1's steps) (line 7)
      vim.api.nvim_win_set_cursor(0, { 7, 0 })
      local run_idx, job_idx = cursor_tracker.get_job_at_cursor(runs)
      assert.equals(1, run_idx)
      assert.equals(2, job_idx)
    end)

    it('should return nil when runs is empty', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)

      local runs = {}
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'No runs' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local run_idx, job_idx = cursor_tracker.get_job_at_cursor(runs)
      assert.is_nil(run_idx)
      assert.is_nil(job_idx)
    end)
  end)
end)
