-- Test for workflow input module

---@diagnostic disable: need-check-nil, param-type-mismatch, missing-parameter, redundant-parameter

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

describe('workflow.input', function()
  local input = require('github-actions.workflow.input')

  describe('validate_input', function()
    it('should accept valid required input', function()
      local input_def = { name = 'version', required = true }
      local is_valid, error_message = input.validate_input(input_def, '1.0.0')

      assert.is_true(is_valid)
      assert.is_nil(error_message)
    end)

    it('should reject empty required input', function()
      local input_def = { name = 'version', required = true }
      local is_valid, error_message = input.validate_input(input_def, '')

      assert.is_false(is_valid)
      assert.equals('Input "version" is required', error_message)
    end)

    it('should reject nil required input', function()
      local input_def = { name = 'version', required = true }
      local is_valid, error_message = input.validate_input(input_def, nil)

      assert.is_false(is_valid)
      assert.equals('Input "version" is required', error_message)
    end)

    it('should accept empty optional input', function()
      local input_def = { name = 'tag', required = false }
      local is_valid, error_message = input.validate_input(input_def, '')

      assert.is_true(is_valid)
      assert.is_nil(error_message)
    end)

    it('should accept nil optional input', function()
      local input_def = { name = 'tag', required = false }
      local is_valid, error_message = input.validate_input(input_def, nil)

      assert.is_true(is_valid)
      assert.is_nil(error_message)
    end)

    it('should accept value for optional input', function()
      local input_def = { name = 'tag', required = false }
      local is_valid, error_message = input.validate_input(input_def, 'v1.0.0')

      assert.is_true(is_valid)
      assert.is_nil(error_message)
    end)
  end)

  describe('collect_inputs', function()
    it('should return empty array for no inputs', function()
      local success_called = false
      local result_values = nil

      input.collect_inputs({}, {
        on_success = function(values)
          success_called = true
          result_values = values
        end,
        on_error = function(_)
          error('Should not be called')
        end,
      })

      assert.is_true(success_called)
      assert.same({}, result_values)
    end)

    it('should collect single input value', function()
      local stub = require('luassert.stub')
      local inputs = {
        { name = 'version', description = 'Version to deploy', required = true },
      }

      local success_called = false
      local result_values = nil

      -- Stub vim.ui.input
      stub(vim.ui, 'input')
      vim.ui.input.invokes(function(opts, on_confirm)
        assert.equals('Version to deploy (required):', opts.prompt)
        on_confirm('1.0.0')
      end)

      input.collect_inputs(inputs, {
        on_success = function(values)
          success_called = true
          result_values = values
        end,
        on_error = function(_)
          error('Should not be called')
        end,
      })

      -- Wait for vim.schedule
      vim.wait(100, function()
        return success_called
      end)

      assert.is_true(success_called)
      assert.equals(1, #result_values)
      assert.equals('version', result_values[1].name)
      assert.equals('1.0.0', result_values[1].value)
    end)

    it('should collect multiple input values', function()
      local stub = require('luassert.stub')
      local inputs = {
        { name = 'version', description = 'Version', required = true },
        { name = 'environment', description = 'Environment', required = false, default = 'staging' },
      }

      local success_called = false
      local result_values = nil
      local call_count = 0

      -- Stub vim.ui.input
      stub(vim.ui, 'input')
      vim.ui.input.invokes(function(opts, on_confirm)
        call_count = call_count + 1
        if call_count == 1 then
          assert.equals('Version (required):', opts.prompt)
          on_confirm('1.0.0')
        else
          assert.equals('Environment:', opts.prompt)
          assert.equals('staging', opts.default)
          on_confirm('production')
        end
      end)

      input.collect_inputs(inputs, {
        on_success = function(values)
          success_called = true
          result_values = values
        end,
        on_error = function(_)
          error('Should not be called')
        end,
      })

      -- Wait for vim.schedule
      vim.wait(100, function()
        return success_called
      end)

      assert.is_true(success_called)
      assert.equals(2, #result_values)
      assert.equals('version', result_values[1].name)
      assert.equals('1.0.0', result_values[1].value)
      assert.equals('environment', result_values[2].name)
      assert.equals('production', result_values[2].value)
    end)

    it('should skip empty optional inputs', function()
      local stub = require('luassert.stub')
      local inputs = {
        { name = 'version', description = 'Version', required = true },
        { name = 'tag', description = 'Tag', required = false },
      }

      local success_called = false
      local result_values = nil
      local call_count = 0

      -- Stub vim.ui.input
      stub(vim.ui, 'input')
      vim.ui.input.invokes(function(_, on_confirm)
        call_count = call_count + 1
        if call_count == 1 then
          on_confirm('1.0.0')
        else
          on_confirm('') -- Empty optional input
        end
      end)

      input.collect_inputs(inputs, {
        on_success = function(values)
          success_called = true
          result_values = values
        end,
        on_error = function(_)
          error('Should not be called')
        end,
      })

      -- Wait for vim.schedule
      vim.wait(100, function()
        return success_called
      end)

      assert.is_true(success_called)
      assert.equals(1, #result_values) -- Only version, tag skipped
      assert.equals('version', result_values[1].name)
    end)

    it('should return error for empty required input', function()
      local stub = require('luassert.stub')
      local inputs = {
        { name = 'version', description = 'Version', required = true },
      }

      local error_called = false
      local result_error = nil

      -- Stub vim.ui.input
      stub(vim.ui, 'input')
      vim.ui.input.invokes(function(_, on_confirm)
        on_confirm('') -- Empty required input
      end)

      input.collect_inputs(inputs, {
        on_success = function(_)
          error('Should not be called')
        end,
        on_error = function(err)
          error_called = true
          result_error = err
        end,
      })

      -- Wait for vim.schedule
      vim.wait(100, function()
        return error_called
      end)

      assert.is_true(error_called)
      assert.equals('Input "version" is required', result_error)
    end)
  end)
end)
