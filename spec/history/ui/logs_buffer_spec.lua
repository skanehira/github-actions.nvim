dofile('spec/minimal_init.lua')

describe('history.ui.logs_buffer', function()
  local logs_buffer = require('github-actions.history.ui.logs_buffer')
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
      local bufnr, winnr = logs_buffer.create_buffer('build / Run tests', 12345)

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
      assert.matches('GitHub Actions.*Logs.*build', bufname)
      assert.matches('#12345', bufname)
    end)

    it('should set up keymaps', function()
      local bufnr, _ = logs_buffer.create_buffer('test / Build', 99999)

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
    it('should render logs in buffer', function()
      local bufnr, _ = logs_buffer.create_buffer('build / Run tests', 12345)

      local logs = [[test (ubuntu-latest, stable)	Set up job	2025-10-18T04:09:32.3975987Z Current runner version: '2.329.0'
test (ubuntu-latest, stable)	Set up job	2025-10-18T04:09:32.4000692Z ##[group]Runner Image Provisioner
test (ubuntu-latest, stable)	Run tests	2025-10-18T04:09:37.1234567Z ##[group]Run npm test
test (ubuntu-latest, stable)	Run tests	2025-10-18T04:09:38.4567890Z
test (ubuntu-latest, stable)	Run tests	2025-10-18T04:09:40.8901234Z PASS spec/example_spec.js
test (ubuntu-latest, stable)	Run tests	2025-10-18T04:09:41.1234567Z Test Suites: 1 passed, 1 total]]

      logs_buffer.render(bufnr, logs)

      -- Get buffer lines
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Should have logs + footer
      assert.is_true(#lines >= 6, 'Should have logs and footer')

      -- Check that logs are rendered
      local content = table.concat(lines, '\n')
      assert.matches('Current runner version', content)
      assert.matches('PASS spec/example_spec.js', content)
    end)

    it('should handle empty logs', function()
      local bufnr = logs_buffer.create_buffer('test / Build', 123)

      logs_buffer.render(bufnr, '')

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Should have empty message + footer
      assert.is_true(#lines >= 1)
      local content = table.concat(lines, '\n')
      assert.matches('No logs available', content)
    end)
  end)
end)
