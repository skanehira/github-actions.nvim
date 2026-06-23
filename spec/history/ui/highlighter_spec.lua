dofile('spec/minimal_init.lua')

describe('history.ui.highlighter', function()
  local highlighter = require('github-actions.history.ui.highlighter')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('get_status_highlight', function()
    local highlights = {
      success = 'TestSuccess',
      failure = 'TestFailure',
      cancelled = 'TestCancelled',
      running = 'TestRunning',
      queued = 'TestQueued',
    }

    it('should return success highlight for completed/success', function()
      local hl = highlighter.get_status_highlight('completed', 'success', highlights)
      assert.equals('TestSuccess', hl)
    end)

    it('should return failure highlight for completed/failure', function()
      local hl = highlighter.get_status_highlight('completed', 'failure', highlights)
      assert.equals('TestFailure', hl)
    end)

    it('should return cancelled highlight for completed/cancelled', function()
      local hl = highlighter.get_status_highlight('completed', 'cancelled', highlights)
      assert.equals('TestCancelled', hl)
    end)

    it('should return cancelled highlight for completed/skipped', function()
      local hl = highlighter.get_status_highlight('completed', 'skipped', highlights)
      assert.equals('TestCancelled', hl)
    end)

    it('should return running highlight for in_progress', function()
      local hl = highlighter.get_status_highlight('in_progress', nil, highlights)
      assert.equals('TestRunning', hl)
    end)

    it('should return queued highlight for queued', function()
      local hl = highlighter.get_status_highlight('queued', nil, highlights)
      assert.equals('TestQueued', hl)
    end)

    it('should return queued highlight as default', function()
      local hl = highlighter.get_status_highlight('unknown', nil, highlights)
      assert.equals('TestQueued', hl)
    end)
  end)

  describe('highlight_run_line', function()
    it('should apply highlights to run line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local ns = vim.api.nvim_create_namespace('test-highlighter')

      -- Sample run line: "✓ #12345 main: feat: add feature  2h ago  5m"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '✓ #12345 main: feat: add feature  2h ago  5m' })

      local run = {
        status = 'completed',
        conclusion = 'success',
      }

      local highlights = {
        success = 'TestSuccess',
        run_id = 'TestRunId',
        branch = 'TestBranch',
        time = 'TestTime',
      }

      highlighter.highlight_run_line(bufnr, ns, 0, run, highlights)

      -- Verify extmarks were created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.is_true(#marks > 0, 'Should create extmarks')
    end)
  end)

  describe('highlight_job_line', function()
    it('should apply highlights to job line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local ns = vim.api.nvim_create_namespace('test-highlighter')

      -- Sample job line: "  ✓ Job: build  3m"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '  ✓ Job: build  3m' })

      local job = {
        status = 'completed',
        conclusion = 'success',
      }

      local highlights = {
        success = 'TestSuccess',
        job_name = 'TestJobName',
        time = 'TestTime',
      }

      highlighter.highlight_job_line(bufnr, ns, 0, job, highlights)

      -- Verify extmarks were created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.is_true(#marks > 0, 'Should create extmarks')
    end)
  end)

  describe('highlight_step_line', function()
    it('should apply highlights to step line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local ns = vim.api.nvim_create_namespace('test-highlighter')

      -- Sample step line: "    ├─ ✓ Setup  10s"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '    ├─ ✓ Setup  10s' })

      local step = {
        status = 'completed',
        conclusion = 'success',
      }

      local highlights = {
        success = 'TestSuccess',
        tree_prefix = 'TestTreePrefix',
        step_name = 'TestStepName',
        time = 'TestTime',
      }

      highlighter.highlight_step_line(bufnr, ns, 0, step, highlights)

      -- Verify extmarks were created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.is_true(#marks > 0, 'Should create extmarks')
    end)

    it('should place tree_prefix extmark over the full ├─ multibyte sequence', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local ns = vim.api.nvim_create_namespace('test-highlighter-tree')

      -- '    ├─ ✓ Setup  10s'
      --  bytes 0-3: spaces, 4-6: '├', 7-9: '─', 10: ' ', 11-13: '✓', 14: ' ', 15-19: 'Setup'
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '    ├─ ✓ Setup  10s' })

      local step = { status = 'completed', conclusion = 'success' }
      local highlights = {
        success = 'TestSuccess',
        tree_prefix = 'TestTreePrefix',
        step_name = 'TestStepName',
        time = 'TestTime',
      }

      highlighter.highlight_step_line(bufnr, ns, 0, step, highlights)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })

      local function find_mark_by_group(group)
        for _, m in ipairs(marks) do
          if m[4] and m[4].hl_group == group then
            return m
          end
        end
        return nil
      end

      local tree_mark = find_mark_by_group('TestTreePrefix')
      assert.is_not_nil(tree_mark, 'tree_prefix extmark must exist')
      ---@cast tree_mark table
      -- mark format: {id, row, col, details}
      assert.equals(4, tree_mark[3], 'tree_prefix should start at byte 4 (after 4 leading spaces)')
      assert.equals(10, tree_mark[4].end_col, 'tree_prefix end_col must be 10 (after full ├─ = 6 bytes)')

      local icon_mark = find_mark_by_group('TestSuccess')
      assert.is_not_nil(icon_mark, 'status icon extmark must exist')
      ---@cast icon_mark table
      assert.equals(11, icon_mark[3], 'status icon should start at byte 11 (after ├─ + space)')
      assert.equals(14, icon_mark[4].end_col, 'status icon end_col must be 14 (after full ✓ = 3 bytes)')
    end)
  end)

  describe('highlight_footer', function()
    it('should apply highlight to footer line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local ns = vim.api.nvim_create_namespace('test-highlighter')

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Press <CR> to expand, q to close' })

      local highlights = {
        time = 'TestTime',
      }

      highlighter.highlight_footer(bufnr, ns, 0, highlights)

      -- Verify extmark was created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.equals(1, #marks, 'Should create one extmark')
    end)
  end)

  describe('apply_highlights', function()
    it('should apply highlights to all runs', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      local runs = {
        {
          status = 'completed',
          conclusion = 'success',
          expanded = false,
        },
      }

      -- Set buffer content
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '✓ #12345 main: feat: add feature  2h ago  5m',
        '',
        'Press <CR> to expand, q to close',
      })

      local highlights = {
        success = 'TestSuccess',
        run_id = 'TestRunId',
        branch = 'TestBranch',
        time = 'TestTime',
      }

      highlighter.apply_highlights(bufnr, runs, highlights)

      -- Verify highlights were applied
      local ns = vim.api.nvim_create_namespace('github-actions-history')
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.is_true(#marks > 0, 'Should create extmarks')
    end)
  end)
end)
