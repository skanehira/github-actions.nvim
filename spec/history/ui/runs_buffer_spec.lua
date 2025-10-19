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

      -- Should have header + separator + 2 runs
      assert.is_true(#lines >= 4, 'Should have at least header, separator, and 2 runs')

      -- Check header
      assert.matches('GitHub Actions', lines[1])

      -- Check separator
      assert.matches('━', lines[2])

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

      -- Should have header + separator + empty message
      assert.is_true(#lines >= 3)
      local content = table.concat(lines, '\n')
      assert.matches('No workflow runs found', content)
    end)
  end)
end)
