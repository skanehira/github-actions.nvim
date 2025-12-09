dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field

describe('shared.picker', function()
  local picker = require('github-actions.shared.picker')

  describe('select_workflow_files', function()
    it('should call callback with selected file path when using vim.ui.select with single selection', function()
      local detector = require('github-actions.shared.workflow')
      local detector_stub = stub(detector, 'find_workflow_files')
      detector_stub.returns({
        '/repo/.github/workflows/ci.yml',
        '/repo/.github/workflows/deploy.yml',
      })

      local ui_select_stub = stub(vim.ui, 'select')
      ui_select_stub.invokes(function(_, _, on_choice)
        -- Simulate selecting ci.yml
        on_choice('ci.yml')
      end)

      local callback_stub = stub.new()

      picker.select_workflow_files({
        prompt = 'Select workflow:',
        on_select = callback_stub,
      })

      -- Verify callback was called with full path
      assert.stub(callback_stub).was_called_with({ '/repo/.github/workflows/ci.yml' })

      ui_select_stub:revert()
      detector_stub:revert()
    end)

    it('should call callback with single file in array when using vim.ui.select (multi_select fallback)', function()
      local detector = require('github-actions.shared.workflow')
      local detector_stub = stub(detector, 'find_workflow_files')
      detector_stub.returns({
        '/repo/.github/workflows/ci.yml',
        '/repo/.github/workflows/deploy.yml',
        '/repo/.github/workflows/test.yml',
      })

      local ui_select_stub = stub(vim.ui, 'select')
      ui_select_stub.invokes(function(items, opts, on_choice)
        -- vim.ui.select only supports single selection
        -- When multi_select is enabled, the selected value is wrapped in an array
        on_choice('test.yml')
      end)

      local callback_stub = stub.new()

      picker.select_workflow_files({
        prompt = 'Select workflow:',
        on_select = callback_stub,
      })

      -- Verify callback was called with array containing single full path
      -- (multi_select mode wraps single selection in array)
      assert.stub(callback_stub).was_called_with({
        '/repo/.github/workflows/test.yml',
      })

      ui_select_stub:revert()
      detector_stub:revert()
    end)

    it('should show error when no workflow files found', function()
      local detector = require('github-actions.shared.workflow')
      local detector_stub = stub(detector, 'find_workflow_files')
      detector_stub.returns({})

      local notify_stub = stub(vim, 'notify')
      local callback_stub = stub.new()

      picker.select_workflow_files({
        prompt = 'Select workflow:',
        on_select = callback_stub,
      })

      -- Verify error notification
      assert.stub(notify_stub).was_called()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.stub(notify_stub).was_called_with(match.matches('No workflow files found'), vim.log.levels.ERROR)

      -- Verify callback was not called
      assert.stub(callback_stub).was_not_called()

      notify_stub:revert()
      detector_stub:revert()
    end)

    it('should not call callback when user cancels selection', function()
      local detector = require('github-actions.shared.workflow')
      local detector_stub = stub(detector, 'find_workflow_files')
      detector_stub.returns({
        '/repo/.github/workflows/ci.yml',
      })

      local ui_select_stub = stub(vim.ui, 'select')
      ui_select_stub.invokes(function(_, _, on_choice)
        -- Simulate user canceling (pressing ESC)
        on_choice(nil)
      end)

      local callback_stub = stub.new()

      picker.select_workflow_files({
        prompt = 'Select workflow:',
        on_select = callback_stub,
      })

      -- Verify callback was not called
      assert.stub(callback_stub).was_not_called()

      ui_select_stub:revert()
      detector_stub:revert()
    end)
  end)
end)
