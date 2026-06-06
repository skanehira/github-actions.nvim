dofile('spec/minimal_init.lua')

describe('history.ui.runs_buffer - float mode', function()
  local runs_buffer = require('github-actions.history.ui.runs_buffer')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match('%[GitHub Actions%]') then
          buffer_helper.delete_buffer(bufnr)
        end
      end
    end
  end)

  describe('open_window with float mode', function()
    it('should create a floating window with default size', function()
      -- Mock the window creation to avoid actually creating UI in tests
      local original_open_win = vim.api.nvim_open_win
      local mock_open_win = function(bufnr, _, opts)
        -- Verify buffer is passed
        assert.is_number(bufnr)
        return 1001 -- Return a fake window ID
      end

      vim.api.nvim_open_win = mock_open_win

      -- Create a test buffer first
      local test_bufnr = vim.api.nvim_create_buf(false, true)

      -- This should not error
      local winid = runs_buffer.open_window('float', test_bufnr)

      -- Restore original function
      vim.api.nvim_open_win = original_open_win

      -- Window ID should be returned
      assert.equals(1001, winid)
    end)

    it('should respect custom window options for float mode', function()
      -- Mock the window creation to avoid actually creating UI in tests
      local original_open_win = vim.api.nvim_open_win
      local captured_opts = nil
      local mock_open_win = function(bufnr, _, opts)
        captured_opts = opts
        return 1001 -- Return a fake window ID
      end

      vim.api.nvim_open_win = mock_open_win

      -- Create a test buffer first
      local test_bufnr = vim.api.nvim_create_buf(false, true)

      -- Call with custom options
      local custom_opts = {
        width = 50,
        height = 20,
        row = 10,
        col = 10
      }

      runs_buffer.open_window('float', test_bufnr, custom_opts)

      -- Restore original function
      vim.api.nvim_open_win = original_open_win

      -- Check that options were passed correctly
      assert.is_not_nil(captured_opts)
      assert.equals(50, captured_opts.width)
      assert.equals(20, captured_opts.height)
      assert.equals(10, captured_opts.row)
      assert.equals(10, captured_opts.col)
    end)

    it('should error when bufnr is not provided for float mode', function()
      local ok, err = pcall(function()
        runs_buffer.open_window('float')
      end)
      assert.is_false(ok)
      assert.matches('bufnr is required for float mode', err)
    end)

    it('should pass title through to nvim_open_win', function()
      local original_open_win = vim.api.nvim_open_win
      local captured_opts = nil
      vim.api.nvim_open_win = function(_, _, opts)
        captured_opts = opts
        return 1001
      end

      local test_bufnr = vim.api.nvim_create_buf(false, true)
      runs_buffer.open_window('float', test_bufnr, { title = 'test title' })

      assert.is_not_nil(captured_opts)
      assert.equals('test title', captured_opts.title)

      vim.api.nvim_open_win = original_open_win
    end)
  end)
end)