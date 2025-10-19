dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

describe('history.init', function()
  local init = require('github-actions.history.init')
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
      system_stub.invokes(function(cmd, opts, callback)
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
      init.show_history(bufnr)
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

      -- Stub vim.notify to capture error message
      local notify_stub = stub(vim, 'notify')

      init.show_history(bufnr)
      flush_scheduled()

      -- Verify error was shown
      assert.stub(notify_stub).was_called()
      assert.stub(notify_stub).was_called_with(match.matches('workflow file'), vim.log.levels.ERROR)

      notify_stub:revert()
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

      -- Stub vim.notify to capture error message
      local notify_stub = stub(vim, 'notify')

      init.show_history(bufnr)
      flush_scheduled()

      -- Verify error was shown
      assert.stub(notify_stub).was_called()
      assert.stub(notify_stub).was_called_with(match.matches('workflow name'), vim.log.levels.ERROR)

      notify_stub:revert()
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

      init.show_history(bufnr)
      flush_scheduled()

      -- Verify error was shown
      assert.stub(notify_stub).was_called()
      assert.stub(notify_stub).was_called_with(match.matches('gh:'), vim.log.levels.ERROR)

      system_stub:revert()
      notify_stub:revert()
    end)
  end)
end)
