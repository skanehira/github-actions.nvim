dofile('spec/minimal_init.lua')

describe('shared.buffer_utils', function()
  local buffer_utils = require('github-actions.shared.buffer_utils')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('find_window_for_buffer', function()
    it('should return nil when buffer is not displayed', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local winid = buffer_utils.find_window_for_buffer(bufnr)
      assert.is_nil(winid)
    end)

    it('should find window in current tab', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid, bufnr)

      local found_winid = buffer_utils.find_window_for_buffer(bufnr)
      assert.equals(winid, found_winid)
    end)

    it('should find window across different tabs', function()
      -- Create buffer in first tab
      local bufnr = vim.api.nvim_create_buf(false, true)
      local winid1 = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid1, bufnr)

      -- Create new tab
      vim.cmd('tabnew')
      local winid2 = vim.api.nvim_get_current_win()

      -- Buffer should still be found in first tab
      local found_winid = buffer_utils.find_window_for_buffer(bufnr)
      assert.equals(winid1, found_winid)
      assert.not_equals(winid2, found_winid)
    end)
  end)

  describe('find_buffer_by_name', function()
    it('should return nil when buffer does not exist', function()
      local bufnr = buffer_utils.find_buffer_by_name('NonExistentBuffer')
      assert.is_nil(bufnr)
    end)

    it('should find buffer by exact name match', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, 'TestBuffer')

      local found_bufnr = buffer_utils.find_buffer_by_name('TestBuffer')
      assert.equals(bufnr, found_bufnr)
    end)

    it('should return first match when multiple buffers exist', function()
      -- This shouldn't happen in practice, but test the behavior
      local bufnr1 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr1, 'DuplicateName')

      local found_bufnr = buffer_utils.find_buffer_by_name('DuplicateName')
      assert.equals(bufnr1, found_bufnr)
    end)
  end)

  describe('focus_or_create_window', function()
    it('should focus window when buffer is already displayed', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local winid1 = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid1, bufnr)

      -- Create new tab
      vim.cmd('tabnew')
      local winid2 = vim.api.nvim_get_current_win()

      -- Should not create new window, just return existing one
      local result_winid = buffer_utils.focus_or_create_window(bufnr, {})
      assert.equals(winid1, result_winid)
    end)

    it('should create vertical split when buffer not displayed', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local initial_win_count = #vim.api.nvim_list_wins()

      local winid = buffer_utils.focus_or_create_window(bufnr, { split = 'vertical' })

      assert.is_not_nil(winid)
      assert.is_true(vim.api.nvim_win_is_valid(winid))
      assert.equals(bufnr, vim.api.nvim_win_get_buf(winid))
      -- Should have created a new window
      assert.equals(initial_win_count + 1, #vim.api.nvim_list_wins())
    end)

    it('should create horizontal split when specified', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local initial_win_count = #vim.api.nvim_list_wins()

      local winid = buffer_utils.focus_or_create_window(bufnr, { split = 'horizontal' })

      assert.is_not_nil(winid)
      assert.is_true(vim.api.nvim_win_is_valid(winid))
      assert.equals(bufnr, vim.api.nvim_win_get_buf(winid))
      assert.equals(initial_win_count + 1, #vim.api.nvim_list_wins())
    end)

    it('should use current window when no split specified and buffer not displayed', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local initial_winid = vim.api.nvim_get_current_win()

      local winid = buffer_utils.focus_or_create_window(bufnr, {})

      -- Should reuse current window
      assert.equals(initial_winid, winid)
      assert.equals(bufnr, vim.api.nvim_win_get_buf(winid))
    end)
  end)
end)
