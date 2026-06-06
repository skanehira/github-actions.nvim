dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

--- Flush all pending vim.schedule callbacks
local function flush_scheduled()
  vim.wait(0, function()
    return false
  end)
end

describe('pr.init', function()
  local pr_init
  local stub = require('luassert.stub')
  local pr_api
  local select_mod
  local history_api

  before_each(function()
    -- Clear cached modules
    package.loaded['github-actions.pr.init'] = nil
    package.loaded['github-actions.pr.api'] = nil
    package.loaded['github-actions.shared.select'] = nil
    package.loaded['github-actions.history.api'] = nil
    package.loaded['github-actions.history.ui.runs_buffer'] = nil

    pr_api = require('github-actions.pr.api')
    select_mod = require('github-actions.shared.select')
    history_api = require('github-actions.history.api')
    pr_init = require('github-actions.pr.init')
  end)

  after_each(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == 'nofile' then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)

  describe('show_pr_history', function()
    it('should fetch branches with PRs and show picker', function()
      -- Stub pr_api.get_current_branch
      stub(pr_api, 'get_current_branch')
      pr_api.get_current_branch.returns('feature/my-branch')

      -- Stub pr_api.fetch_branches_with_prs
      stub(pr_api, 'fetch_branches_with_prs')
      pr_api.fetch_branches_with_prs.invokes(function(callback)
        callback({
          { branch = 'main' },
          { branch = 'feature/my-branch', pr_number = 42, pr_title = 'My PR' },
        }, nil)
      end)

      -- Stub select.select
      local captured_opts = nil
      stub(select_mod, 'select')
      select_mod.select.invokes(function(opts)
        captured_opts = opts
        -- Don't call on_select to avoid needing more stubs
      end)

      pr_init.show_pr_history()

      flush_scheduled()

      -- Verify select was called with correct options
      assert.stub(select_mod.select).was_called()
      assert.is_not_nil(captured_opts)
      assert.equals('Select branch:', captured_opts.prompt)
      assert.equals('feature/my-branch', captured_opts.default_text)
      assert.equals(2, #captured_opts.items)

      -- Verify display format
      local branch_with_pr = nil
      local branch_without_pr = nil
      for _, item in ipairs(captured_opts.items) do
        if item.value == 'feature/my-branch' then
          branch_with_pr = item
        elseif item.value == 'main' then
          branch_without_pr = item
        end
      end

      assert.is_not_nil(branch_with_pr)
      assert.equals('feature/my-branch #42', branch_with_pr.display)

      assert.is_not_nil(branch_without_pr)
      assert.equals('main', branch_without_pr.display)

      pr_api.get_current_branch:revert()
      pr_api.fetch_branches_with_prs:revert()
      select_mod.select:revert()
    end)

    it('should pass open_mode and window_options to create_buffer', function()
      stub(pr_api, 'get_current_branch')
      pr_api.get_current_branch.returns('feature/branch')

      stub(pr_api, 'fetch_branches_with_prs')
      pr_api.fetch_branches_with_prs.invokes(function(callback)
        callback({ { branch = 'feature/branch', pr_number = 1 } }, nil)
      end)

      -- Stub runs_buffer.create_buffer to capture opts
      local runs_buffer = require('github-actions.history.ui.runs_buffer')
      local captured_create_opts = nil
      stub(runs_buffer, 'create_buffer')
      runs_buffer.create_buffer.invokes(function(_, _, opts)
        captured_create_opts = opts
        return 1, 1
      end)
      stub(runs_buffer, 'show_loading')

      -- Stub history_api.fetch_runs_by_branch to avoid network
      stub(history_api, 'fetch_runs_by_branch')

      -- Stub select.select to trigger on_select
      stub(select_mod, 'select')
      select_mod.select.invokes(function(opts)
        opts.on_select('feature/branch')
      end)

      pr_init.show_pr_history({
        buffer = {
          history = {
            open_mode = 'float',
            window_options = { width = 0.5 },
          },
        },
      })

      flush_scheduled()

      assert.stub(runs_buffer.create_buffer).was_called()
      assert.is_not_nil(captured_create_opts)
      assert.equals('float', captured_create_opts.open_mode)
      assert.equals(0.5, captured_create_opts.window_options.width)

      pr_api.get_current_branch:revert()
      pr_api.fetch_branches_with_prs:revert()
      runs_buffer.create_buffer:revert()
      runs_buffer.show_loading:revert()
      history_api.fetch_runs_by_branch:revert()
      select_mod.select:revert()
    end)

    it('should show warning when no branches found', function()
      stub(pr_api, 'get_current_branch')
      pr_api.get_current_branch.returns('main')

      stub(pr_api, 'fetch_branches_with_prs')
      pr_api.fetch_branches_with_prs.invokes(function(callback)
        callback({}, nil) -- Empty list
      end)

      local notify_called = false
      local notify_level = nil
      stub(vim, 'notify')
      vim.notify.invokes(function(msg, level)
        notify_called = true
        notify_level = level
      end)

      pr_init.show_pr_history()

      flush_scheduled()

      assert.is_true(notify_called)
      assert.equals(vim.log.levels.WARN, notify_level)

      pr_api.get_current_branch:revert()
      pr_api.fetch_branches_with_prs:revert()
      vim.notify:revert()
    end)

    it('should show error when fetch_branches_with_prs fails', function()
      stub(pr_api, 'get_current_branch')
      pr_api.get_current_branch.returns('main')

      stub(pr_api, 'fetch_branches_with_prs')
      pr_api.fetch_branches_with_prs.invokes(function(callback)
        callback(nil, 'Network error')
      end)

      local notify_called = false
      local notify_message = nil
      stub(vim, 'notify')
      vim.notify.invokes(function(msg)
        notify_called = true
        notify_message = msg
      end)

      pr_init.show_pr_history()

      flush_scheduled()

      assert.is_true(notify_called)
      assert.matches('Network error', notify_message)

      pr_api.get_current_branch:revert()
      pr_api.fetch_branches_with_prs:revert()
      vim.notify:revert()
    end)
  end)
end)
