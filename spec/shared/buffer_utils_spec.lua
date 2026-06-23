dofile('spec/minimal_init.lua')

describe('shared.buffer_utils', function()
  local buffer_utils = require('github-actions.shared.buffer_utils')
  local buffer_helper = require('spec.helpers.buffer_spec')

  local mocks = {}

  local function setup_mock(target, key, mock_fn)
    table.insert(mocks, { target = target, key = key, original = target[key] })
    target[key] = mock_fn
  end

  after_each(function()
    for _, mock in ipairs(mocks) do
      mock.target[mock.key] = mock.original
    end
    mocks = {}
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
      local bufnr = vim.api.nvim_create_buf(false, true)
      local winid1 = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid1, bufnr)

      vim.cmd('tabnew')
      local winid2 = vim.api.nvim_get_current_win()

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

      vim.cmd('tabnew')
      local winid2 = vim.api.nvim_get_current_win()

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

      assert.equals(initial_winid, winid)
      assert.equals(bufnr, vim.api.nvim_win_get_buf(winid))
    end)
  end)

  describe('open_float_window', function()
    it('should pass title through to nvim_open_win', function()
      local captured_opts = nil
      setup_mock(vim.api, 'nvim_open_win', function(_, _, opts)
        captured_opts = opts
        return 1001
      end)

      local bufnr = vim.api.nvim_create_buf(false, true)
      buffer_utils.open_float_window(bufnr, {}, { title = 'test title' })

      assert.is_not_nil(captured_opts)
      assert.equals('test title', captured_opts.title)
    end)

    it('should not set title when not provided', function()
      local captured_opts = nil
      setup_mock(vim.api, 'nvim_open_win', function(_, _, opts)
        captured_opts = opts
        return 1001
      end)

      local bufnr = vim.api.nvim_create_buf(false, true)
      buffer_utils.open_float_window(bufnr, {}, {})

      assert.is_not_nil(captured_opts)
      assert.is_nil(captured_opts.title)
    end)
  end)

  describe('open_terminal_float', function()
    it('should create buffer and open float window for terminal', function()
      local captured_float_opts = nil
      setup_mock(vim.api, 'nvim_open_win', function(_, _, opts)
        captured_float_opts = opts
        return 1001
      end)
      local jobstart_called = false
      setup_mock(vim.fn, 'jobstart', function(cmd, _)
        jobstart_called = true
        assert.equals('gh', cmd[1])
        assert.equals('run', cmd[2])
        assert.equals('watch', cmd[3])
        assert.equals('12345', cmd[4])
        return 1
      end)

      local bufnr, winid = buffer_utils.open_terminal_float(
        { 'gh', 'run', 'watch', '12345' },
        { window_geometry_options = { title = 'Watch - ci.yml' } }
      )

      assert.is_not_nil(bufnr)
      assert.equals(1001, winid)
      assert.is_true(jobstart_called)
      assert.equals('Watch - ci.yml', captured_float_opts.title)
    end)

    it('should call on_exit callback when terminal exits', function()
      setup_mock(vim.api, 'nvim_open_win', function(_, _, _)
        return 1001
      end)
      setup_mock(vim.fn, 'jobstart', function()
        return 1
      end)

      local on_exit_called = false
      local bufnr, _ = buffer_utils.open_terminal_float({ 'gh', 'run', 'watch', '12345' }, {
        window_geometry_options = { title = 'Watch - ci.yml' },
        on_exit = function()
          on_exit_called = true
        end,
      })

      vim.api.nvim_exec_autocmds('TermClose', { buffer = bufnr })
      vim.wait(0, function()
        return false
      end)

      assert.is_true(on_exit_called)
    end)

    it('should close buffer and window when pressing q', function()
      setup_mock(vim.fn, 'jobstart', function()
        return 1
      end)

      local bufnr, winid = buffer_utils.open_terminal_float({ 'echo', 'test' })

      assert.is_true(vim.api.nvim_buf_is_valid(bufnr), 'buffer should be initially valid')
      assert.is_true(vim.api.nvim_win_is_valid(winid), 'window should be initially valid')

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local q_callback = nil
      for _, m in ipairs(maps) do
        if m.lhs == 'q' then
          q_callback = m.callback
          break
        end
      end
      assert.is_not_nil(q_callback, 'q keymap should exist on terminal buffer')

      q_callback()

      -- Window close is synchronous
      assert.is_false(vim.api.nvim_win_is_valid(winid), 'window should be closed after q')
      -- Buffer delete is scheduled (avoid E937), so wait for it
      local closed = vim.wait(1000, function()
        return not vim.api.nvim_buf_is_valid(bufnr)
      end, 10)
      assert.is_true(closed, 'buffer should be closed after q')
    end)
  end)

  describe('open_terminal (non-float modes)', function()
    it('should bind q to close window and buffer when opened in current mode', function()
      setup_mock(vim.fn, 'jobstart', function()
        return 1
      end)
      vim.cmd('split') -- ensure the terminal window is not the last one

      local bufnr, winid = buffer_utils.open_terminal('current', { 'echo', 'test' })

      assert.is_true(vim.api.nvim_buf_is_valid(bufnr), 'buffer should be initially valid')
      assert.is_true(vim.api.nvim_win_is_valid(winid), 'window should be initially valid')

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local q_callback = nil
      for _, m in ipairs(maps) do
        if m.lhs == 'q' then
          q_callback = m.callback
          break
        end
      end
      assert.is_not_nil(q_callback, 'q keymap should exist on non-float terminal buffer')

      q_callback()

      assert.is_false(vim.api.nvim_win_is_valid(winid), 'window should be closed after q')
      local closed = vim.wait(1000, function()
        return not vim.api.nvim_buf_is_valid(bufnr)
      end, 10)
      assert.is_true(closed, 'buffer should be closed after q')
    end)
  end)
end)
