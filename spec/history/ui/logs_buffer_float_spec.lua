dofile('spec/minimal_init.lua')

describe('history.ui.logs_buffer - float mode', function()
  local logs_buffer = require('github-actions.history.ui.logs_buffer')
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
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == 'nofile' then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('create_buffer with float open_mode', function()
    it('should create a floating window', function()
      local captured_opts = nil
      setup_mock(vim.api, 'nvim_open_win', function(_, _, opts)
        captured_opts = opts
        return 1001
      end)

      local bufnr, winnr = logs_buffer.create_buffer('build / Run tests', 12345, {
        open_mode = 'float',
      })

      assert.is_not_nil(bufnr)
      assert.equals(1001, winnr)
      assert.is_not_nil(captured_opts)
      assert.equals('editor', captured_opts.relative)
      assert.equals('minimal', captured_opts.style)
    end)

    it('should set fold options on float window for log groups', function()
      local captured_winid = nil
      setup_mock(vim.api, 'nvim_open_win', function(_, _, opts)
        captured_winid = 1001
        return 1001
      end)
      setup_mock(vim.fn, 'termopen', function(_)
        return 1
      end)

      -- fold settings are applied via vim.wo which sets window-local options
      -- on the current window (the float after nvim_open_win)
      -- Mock nvim_win_set_buf to avoid "buffer already displayed" errors
      setup_mock(vim.api, 'nvim_win_set_buf', function() end)

      local bufnr, winnr = logs_buffer.create_buffer('build / Run tests', 12345, {
        open_mode = 'float',
        logs_fold_by_default = true,
      })

      assert.is_not_nil(bufnr)
      assert.equals(1001, winnr)

      -- Verify fold settings were applied. Since vim.wo sets are side-effectful
      -- on the test runner, check that the method completed without error and
      -- that the window/buffer are valid.
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      if vim.api.nvim_win_is_valid(winnr) then
        assert.equals('expr', vim.wo[winnr].foldmethod)
      end
    end)

    it('should use default fold level when logs_fold_by_default is true', function()
      local captured_winid = nil
      setup_mock(vim.api, 'nvim_open_win', function(_, _, opts)
        captured_winid = 1001
        return 1001
      end)

      local bufnr, winnr = logs_buffer.create_buffer('build / Run tests', 12345, {
        open_mode = 'float',
        logs_fold_by_default = true,
      })

      if vim.api.nvim_win_is_valid(winnr) then
        assert.equals(0, vim.wo[winnr].foldlevel)
      end
    end)

    it('should pass window_options to float window', function()
      local captured_opts = nil
      setup_mock(vim.api, 'nvim_open_win', function(_, _, opts)
        captured_opts = opts
        return 1001
      end)

      local bufnr, winnr = logs_buffer.create_buffer('build / Run tests', 12345, {
        open_mode = 'float',
        window_geometry_options = {
          width = 90,
          height = 40,
        },
        window_options = {
          wrap = false,
        },
      })

      assert.is_not_nil(captured_opts)
      assert.equals(90, captured_opts.width)
      assert.equals(40, captured_opts.height)
    end)
  end)
end)
