dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

describe('history.init', function()
  local history = require('github-actions.history')
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
    it('should show workflow run history for a workflow file', function()
      -- Create a test workflow file
      local workflow_content = [[
name: CI
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
]]
      local bufnr = buffer_helper.create_yaml_buffer(workflow_content)
      local bufname = '.github/workflows/ci.yml'
      vim.api.nvim_buf_set_name(bufnr, bufname)

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

      -- Call show_history
      history.show_history(bufnr, {})
      flush_scheduled()

      -- Verify a new buffer was created
      local bufs = vim.api.nvim_list_bufs()
      local history_buf = nil
      for _, buf in ipairs(bufs) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'nofile' then
          local name = vim.api.nvim_buf_get_name(buf)
          if name:match('Run History') then
            history_buf = buf
            break
          end
        end
      end

      assert.is.not_nil(history_buf, 'History buffer should be created')

      -- Verify buffer content contains the run
      local lines = vim.api.nvim_buf_get_lines(history_buf, 0, -1, false)
      local content = table.concat(lines, '\n')
      assert.matches('#12345', content)
      assert.matches('feat: add feature', content)

      system_stub:revert()
    end)

    it('should show error when not a workflow file', function()
      -- Create a non-workflow file
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, 'test.lua')

      -- Stub detector.find_workflow_files to return empty array
      local detector = require('github-actions.shared.workflow')
      local detector_stub = stub(detector, 'find_workflow_files')
      detector_stub.returns({})

      -- Stub vim.notify to capture error message
      local notify_stub = stub(vim, 'notify')

      history.show_history(bufnr, {})
      flush_scheduled()

      -- Verify error was shown
      assert.stub(notify_stub).was_called()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.stub(notify_stub).was_called_with(match.matches('No workflow files found'), vim.log.levels.ERROR)

      notify_stub:revert()
      detector_stub:revert()
    end)

    it('should show error when workflow name not found', function()
      -- Create a workflow file without name field
      local workflow_content = [[
on: push
jobs:
  test:
    runs-on: ubuntu-latest
]]
      local bufnr = buffer_helper.create_yaml_buffer(workflow_content)
      vim.api.nvim_buf_set_name(bufnr, '.github/workflows/test.yml')

      -- Stub detector.find_workflow_files to return empty array
      -- When workflow file is invalid (no name field), it falls back to file selection
      local detector = require('github-actions.shared.workflow')
      local detector_stub = stub(detector, 'find_workflow_files')
      detector_stub.returns({})

      -- Stub vim.notify to capture error message
      local notify_stub = stub(vim, 'notify')

      history.show_history(bufnr, {})
      flush_scheduled()

      -- Verify error was shown
      -- New behavior: if current buffer is not a valid workflow file,
      -- it tries to find workflow files in .github/workflows/
      -- Since we stubbed find_workflow_files to return empty, it shows "No workflow files found"
      assert.stub(notify_stub).was_called()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.stub(notify_stub).was_called_with(match.matches('No workflow files found'), vim.log.levels.ERROR)

      notify_stub:revert()
      detector_stub:revert()
    end)

    it('should show error when gh CLI fails', function()
      -- Create a test workflow file
      local workflow_content = [[
name: CI
on: push
]]
      local bufnr = buffer_helper.create_yaml_buffer(workflow_content)
      vim.api.nvim_buf_set_name(bufnr, '.github/workflows/ci.yml')

      -- Stub vim.system to return error
      local system_stub = stub(vim, 'system')
      system_stub.invokes(function(cmd, opts, callback)
        if cmd[1] == 'gh' and cmd[2] == 'run' and cmd[3] == 'list' then
          vim.schedule(function()
            callback({
              code = 1,
              stdout = '',
              stderr = 'gh: command not found',
            })
          end)
        end
      end)

      -- Stub vim.notify to capture error message
      local notify_stub = stub(vim, 'notify')

      history.show_history(bufnr, {})
      flush_scheduled()

      -- Verify error was shown
      assert.stub(notify_stub).was_called()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.stub(notify_stub).was_called_with(match.matches('gh:'), vim.log.levels.ERROR)

      system_stub:revert()
      notify_stub:revert()
    end)

    it('should open multiple tabs when multiple workflow files are selected', function()
      -- Create a non-workflow buffer (so it triggers file selection)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, 'test.lua')

      -- Stub detector.find_workflow_files to return multiple files
      local detector = require('github-actions.shared.workflow')
      local detector_stub = stub(detector, 'find_workflow_files')
      local workflow_files = {
        '/repo/.github/workflows/ci.yml',
        '/repo/.github/workflows/deploy.yml',
        '/repo/.github/workflows/test.yml',
      }
      detector_stub.returns(workflow_files)

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

      -- Stub vim.ui.select to simulate multiple selection
      local ui_select_stub = stub(vim.ui, 'select')
      ui_select_stub.invokes(function(_, opts, on_choice)
        -- Simulate selecting ci.yml and test.yml (indices 1 and 3)
        -- In telescope multi-select, the callback receives a table of selected items
        if opts.prompt:match('Select workflow') then
          on_choice({ 'ci.yml', 'test.yml' })
        end
      end)

      -- Store initial tab count
      local initial_tabs = vim.fn.tabpagenr('$')

      -- Call show_history
      history.show_history(bufnr, {})
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
      ui_select_stub:revert()
      detector_stub:revert()
    end)
  end)
end)
