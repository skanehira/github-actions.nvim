dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

describe('dispatch.init', function()
  local dispatch = require('github-actions.dispatch')
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
      if vim.api.nvim_buf_is_valid(bufnr) then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('dispatch_workflow', function()
    it('should always call picker regardless of buffer type', function()
      -- Create a valid workflow file buffer with workflow_dispatch
      local workflow_content = [[
name: Deploy
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
jobs:
  deploy:
    runs-on: ubuntu-latest
]]
      local bufnr = buffer_helper.create_yaml_buffer(workflow_content)
      vim.api.nvim_buf_set_name(bufnr, '.github/workflows/deploy.yml')

      -- Stub picker.select_workflow_files to track if it's called
      local picker_stub = stub(picker, 'select_workflow_files')
      picker_stub.invokes(function(_)
        -- Simulate user canceling selection to avoid side effects
      end)

      -- Call dispatch_workflow with workflow buffer
      dispatch.dispatch_workflow()
      flush_scheduled()

      -- Assert picker was called even though buffer is a valid workflow file
      -- This will FAIL with current implementation because it bypasses picker for workflow files
      assert.stub(picker_stub).was_called(1)
      assert.stub(picker_stub).was_called_with(match.is_table())

      picker_stub:revert()
    end)

    it('should invoke callback for selected workflow file with workflow_dispatch validation', function()
      -- Track calls to dispatch_workflow_for_file via parser.parse_workflow_dispatch
      local dispatch_calls = {}

      -- Stub picker to capture and trigger callback
      local picker_stub = stub(picker, 'select_workflow_files')
      picker_stub.invokes(function(opts)
        -- Simulate user selecting a workflow file
        local selected_paths = {
          '.github/workflows/deploy.yml',
        }

        -- Capture the on_select callback
        local on_select = opts.on_select
        assert.is_function(on_select, 'on_select should be a function')

        -- Trigger the callback with selected path
        on_select(selected_paths)
      end)

      -- Stub parser to track which files are being validated
      local parser = require('github-actions.dispatch.parser')
      local parser_stub = stub(parser, 'parse_workflow_dispatch')
      parser_stub.invokes(function(buf)
        -- Track that parse_workflow_dispatch was called
        local filepath = vim.api.nvim_buf_get_name(buf)
        local filename = filepath:match('[^/]+%.ya?ml$')
        table.insert(dispatch_calls, filename)
        -- Return valid workflow_dispatch configuration
        return {
          inputs = {},
        }
      end)

      -- Stub branch_picker to prevent actual branch selection UI
      local branch_picker = require('github-actions.dispatch.branch_picker')
      local branch_stub = stub(branch_picker, 'select_branch')

      -- Call dispatch_workflow
      dispatch.dispatch_workflow()
      flush_scheduled()

      -- Verify dispatch_workflow_for_file was called with first selected path
      assert.equals(1, #dispatch_calls, 'Should call dispatch_workflow_for_file once')
      assert.equals('deploy.yml', dispatch_calls[1])

      parser_stub:revert()
      picker_stub:revert()
      branch_stub:revert()
    end)

    it('should show error when workflow does not support workflow_dispatch', function()
      -- Stub picker to simulate selection
      local picker_stub = stub(picker, 'select_workflow_files')
      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      -- Stub parser to return nil (no workflow_dispatch support)
      local parser = require('github-actions.dispatch.parser')
      local parser_stub = stub(parser, 'parse_workflow_dispatch')
      parser_stub.returns(nil)

      -- Stub vim.notify to capture error message
      local notify_stub = stub(vim, 'notify')

      -- Call dispatch_workflow
      dispatch.dispatch_workflow()
      flush_scheduled()

      -- Verify error was shown
      assert.stub(notify_stub).was_called()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert
        .stub(notify_stub)
        .was_called_with(match.matches('does not support workflow_dispatch'), vim.log.levels.ERROR)

      notify_stub:revert()
      parser_stub:revert()
      picker_stub:revert()
    end)
  end)
end)
