dofile('spec/minimal_init.lua')

describe('lib.highlights', function()
  local highlights
  local stub = require('luassert.stub')

  before_each(function()
    package.loaded['github-actions.lib.highlights'] = nil
    highlights = require('github-actions.lib.highlights')
  end)

  describe('setup', function()
    local function capture_set_hl()
      local captured = {}
      stub(vim.api, 'nvim_set_hl')
      vim.api.nvim_set_hl.invokes(function(_, group, opts)
        captured[group] = opts
      end)
      return captured
    end

    after_each(function()
      if vim.api.nvim_set_hl.revert then
        vim.api.nvim_set_hl:revert()
      end
    end)

    it('should register defaults with default=true so colorschemes can override', function()
      local captured = capture_set_hl()

      highlights.setup(nil)

      assert.is_not_nil(captured.GitHubActionsHistorySuccess, 'success group must be registered')
      assert.is_true(captured.GitHubActionsHistorySuccess.default, 'untouched defaults must carry default=true')
    end)

    it('should strip default=true from groups the user customised', function()
      local captured = capture_set_hl()

      highlights.setup({
        success = { fg = '#abcdef', bold = false },
      })

      local group = captured.GitHubActionsHistorySuccess
      assert.is_not_nil(group, 'customised group must still be registered')
      assert.equals('#abcdef', group.fg, 'user fg must be applied')
      assert.is_nil(group.default, 'user-customised group must not carry default=true (otherwise colorscheme silently wins)')
    end)

    it('should leave default=true on groups the user did not customise', function()
      local captured = capture_set_hl()

      highlights.setup({
        success = { fg = '#abcdef' },
      })

      assert.is_true(captured.GitHubActionsHistoryFailure.default,
        'unrelated groups must keep default=true')
    end)
  end)
end)
