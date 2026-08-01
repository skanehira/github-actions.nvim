dofile('spec/minimal_init.lua')

describe('history.ui.loading_indicator', function()
  local loading_indicator = require('github-actions.history.ui.loading_indicator')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('show', function()
    it('should add virtual text at current cursor line', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1', 'Line 2', 'Line 3' })

      -- Move cursor to line 2
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      local line_idx = loading_indicator.show(bufnr)

      -- Should return line index (0-based)
      assert.equals(1, line_idx)

      -- Check that extmark was created
      local ns = vim.api.nvim_create_namespace('github-actions-loading')
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.equals(1, #marks, 'Should create one extmark')
    end)

    it('should add virtual text at the given line with the given text and namespace', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1', 'Line 2', 'Line 3' })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      local line_idx = loading_indicator.show(bufnr, {
        line = 0,
        text = ' (Refreshing...)',
        namespace = 'github-actions-refreshing',
      })

      assert.equals(0, line_idx)

      local ns = vim.api.nvim_create_namespace('github-actions-refreshing')
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
      assert.equals(1, #marks)
      assert.equals(0, marks[1][2])
      assert.same({ { ' (Refreshing...)', 'GitHubActionsHistoryTime' } }, marks[1][4].virt_text)
    end)

    it('should not touch indicators in other namespaces', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1', 'Line 2' })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      loading_indicator.show(bufnr, { line = 0, text = ' (Refreshing...)', namespace = 'github-actions-refreshing' })
      loading_indicator.show(bufnr)
      loading_indicator.clear(bufnr)

      local refreshing_ns = vim.api.nvim_create_namespace('github-actions-refreshing')
      local loading_ns = vim.api.nvim_create_namespace('github-actions-loading')
      assert.equals(1, #vim.api.nvim_buf_get_extmarks(bufnr, refreshing_ns, 0, -1, {}))
      assert.equals(0, #vim.api.nvim_buf_get_extmarks(bufnr, loading_ns, 0, -1, {}))
    end)

    it('should clear existing loading indicators before adding new one', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1', 'Line 2', 'Line 3' })

      -- Show indicator at line 1
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      loading_indicator.show(bufnr)

      -- Show indicator at line 2 (should clear previous)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      loading_indicator.show(bufnr)

      -- Should only have one extmark
      local ns = vim.api.nvim_create_namespace('github-actions-loading')
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.equals(1, #marks, 'Should only have one extmark')
    end)
  end)

  describe('clear', function()
    it('should clear all loading indicators', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1', 'Line 2' })

      -- Add loading indicator
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      loading_indicator.show(bufnr)

      -- Verify extmark exists
      local ns = vim.api.nvim_create_namespace('github-actions-loading')
      local marks_before = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.equals(1, #marks_before)

      -- Clear loading indicator
      loading_indicator.clear(bufnr)

      -- Verify extmark is cleared
      local marks_after = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
      assert.equals(0, #marks_after, 'Should clear all extmarks')
    end)
  end)
end)
