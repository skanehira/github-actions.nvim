dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

describe('history.init', function()
  local history = require('github-actions.history')
  local picker = require('github-actions.shared.picker')
  local buffer_helper = require('spec.helpers.buffer_spec')

  local function flush_scheduled()
    vim.wait(0, function()
      return false
    end)
  end

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == 'nofile' then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('show_history', function()
    it('should always call picker regardless of buffer type', function()
      -- Stub vim.system to prevent actual API calls
      local system_stub = stub(vim, 'system')

      -- Stub picker.select_workflow_files to track if it's called
      local picker_stub = stub(picker, 'select_workflow_files')
      picker_stub.invokes(function(opts)
        -- Simulate user canceling selection to avoid side effects
      end)

      -- Call show_history
      history.show_history({})
      flush_scheduled()

      -- Assert picker was called
      assert.stub(picker_stub).was_called(1)
      assert.stub(picker_stub).was_called_with(match.is_table())

      system_stub:revert()
      picker_stub:revert()
    end)

    it('should invoke callback for each selected workflow file', function()
      -- Track calls to show_history_for_file
      local history_calls = {}

      -- Stub picker to capture and trigger callback
      local picker_stub = stub(picker, 'select_workflow_files')
      picker_stub.invokes(function(opts)
        -- Simulate user selecting multiple workflow files
        local selected_paths = {
          '.github/workflows/ci.yml',
          '.github/workflows/deploy.yml',
          '.github/workflows/test.yml',
        }

        -- Capture the on_select callback
        local on_select = opts.on_select
        assert.is_function(on_select, 'on_select should be a function')

        -- Trigger the callback with selected paths
        on_select(selected_paths)
      end)

      -- Stub vim.system to track show_history_for_file calls
      local system_stub = stub(vim, 'system')
      system_stub.invokes(function(cmd, _, callback)
        if cmd[1] == 'gh' and cmd[2] == 'run' and cmd[3] == 'list' then
          -- Find the --workflow flag and get the workflow file
          for i, arg in ipairs(cmd) do
            if arg == '--workflow' and cmd[i + 1] then
              table.insert(history_calls, cmd[i + 1])
              break
            end
          end

          vim.schedule(function()
            callback({
              code = 0,
              stdout = '[]',
              stderr = '',
            })
          end)
        end
      end)

      -- Call show_history
      history.show_history({})
      flush_scheduled()

      -- Verify show_history_for_file was called for each selected path
      assert.equals(3, #history_calls, 'Should call show_history_for_file 3 times')
      assert.equals('ci.yml', history_calls[1])
      assert.equals('deploy.yml', history_calls[2])
      assert.equals('test.yml', history_calls[3])

      system_stub:revert()
      picker_stub:revert()
    end)

    it('should open multiple tabs when multiple workflow files are selected', function()
      -- Mock gh CLI response
      local mock_runs = [[
[
  {
    "databaseId": 12345,
    "displayTitle": "feat: add feature",
    "headBranch": "main",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2025-10-19T10:00:00Z",
    "updatedAt": "2025-10-19T10:05:00Z"
  }
]
]]

      -- Stub picker to simulate multiple selection
      local picker_stub = stub(picker, 'select_workflow_files')
      picker_stub.invokes(function(opts)
        -- Simulate user selecting 2 workflow files
        local selected_paths = {
          '.github/workflows/ci.yml',
          '.github/workflows/deploy.yml',
        }
        opts.on_select(selected_paths)
      end)

      -- Stub vim.system to return mock data
      local system_stub = stub(vim, 'system')
      system_stub.invokes(function(cmd, _, callback)
        if cmd[1] == 'gh' and cmd[2] == 'run' and cmd[3] == 'list' then
          vim.schedule(function()
            callback({
              code = 0,
              stdout = mock_runs,
              stderr = '',
            })
          end)
        end
      end)

      -- Store initial tab count
      local initial_tabs = vim.fn.tabpagenr('$')

      -- Call show_history
      history.show_history({})
      flush_scheduled()

      -- Verify multiple tabs were created
      -- When selecting 2 files in multi-select mode: both open in new tabs
      -- So we expect initial_tabs + 2 (two new tabs)
      local final_tabs = vim.fn.tabpagenr('$')
      assert.equals(initial_tabs + 2, final_tabs, 'Should create 2 new tabs for 2 selected files')

      -- Verify history buffers were created for both files
      local history_bufs = {}
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'nofile' then
          local name = vim.api.nvim_buf_get_name(buf)
          if name:match('Run History') then
            table.insert(history_bufs, buf)
          end
        end
      end

      assert.equals(2, #history_bufs, 'Should create 2 history buffers')

      system_stub:revert()
      picker_stub:revert()
    end)
  end)
end)
