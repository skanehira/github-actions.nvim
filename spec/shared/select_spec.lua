dofile('spec/minimal_init.lua')

---@diagnostic disable: need-check-nil, param-type-mismatch, missing-parameter, redundant-parameter

describe('shared.select', function()
  local select_mod

  before_each(function()
    package.loaded['github-actions.shared.select'] = nil
    select_mod = require('github-actions.shared.select')
  end)

  describe('select', function()
    it('should call on_select callback with selected item value', function()
      local items = {
        { value = 'first', display = 'First Item' },
        { value = 'second', display = 'Second Item' },
      }

      local original_select = vim.ui.select
      vim.ui.select = function(display_items, opts, on_choice)
        -- Simulate selecting the first item
        on_choice(display_items[1])
      end

      local callback_called = false
      local callback_value = nil

      select_mod.select({
        prompt = 'Select item:',
        items = items,
        on_select = function(value)
          callback_called = true
          callback_value = value
        end,
      })

      assert.is_true(callback_called)
      assert.equals('first', callback_value)

      vim.ui.select = original_select
    end)

    it('should not call callback when user cancels selection', function()
      local items = {
        { value = 'item1', display = 'Item 1' },
      }

      local original_select = vim.ui.select
      vim.ui.select = function(display_items, opts, on_choice)
        on_choice(nil)
      end

      local callback_called = false

      select_mod.select({
        prompt = 'Select:',
        items = items,
        on_select = function(value)
          callback_called = true
        end,
      })

      assert.is_false(callback_called)

      vim.ui.select = original_select
    end)

    it('should pass correct prompt to vim.ui.select', function()
      local items = {
        { value = 'test', display = 'Test' },
      }

      local original_select = vim.ui.select
      local captured_opts = nil
      vim.ui.select = function(display_items, opts, on_choice)
        captured_opts = opts
        on_choice(nil)
      end

      select_mod.select({
        prompt = 'Custom prompt:',
        items = items,
        on_select = function(value) end,
      })

      assert.is_not_nil(captured_opts)
      assert.equals('Custom prompt:', captured_opts.prompt)

      vim.ui.select = original_select
    end)

    it('should display items using display field', function()
      local items = {
        { value = 'a', display = 'Display A' },
        { value = 'b', display = 'Display B' },
      }

      local original_select = vim.ui.select
      local captured_items = nil
      vim.ui.select = function(display_items, opts, on_choice)
        captured_items = display_items
        on_choice(nil)
      end

      select_mod.select({
        prompt = 'Select:',
        items = items,
        on_select = function(value) end,
      })

      assert.is_not_nil(captured_items)
      assert.equals(2, #captured_items)
      assert.equals('Display A', captured_items[1])
      assert.equals('Display B', captured_items[2])

      vim.ui.select = original_select
    end)

    it('should handle selection by index correctly', function()
      local items = {
        { value = { id = 1, name = 'first' }, display = 'First' },
        { value = { id = 2, name = 'second' }, display = 'Second' },
        { value = { id = 3, name = 'third' }, display = 'Third' },
      }

      local original_select = vim.ui.select
      vim.ui.select = function(display_items, opts, on_choice)
        -- Select second item
        on_choice(display_items[2])
      end

      local callback_value = nil

      select_mod.select({
        prompt = 'Select:',
        items = items,
        on_select = function(value)
          callback_value = value
        end,
      })

      assert.is_not_nil(callback_value)
      assert.equals(2, callback_value.id)
      assert.equals('second', callback_value.name)

      vim.ui.select = original_select
    end)

    it('should handle empty items list gracefully', function()
      local items = {}

      local original_select = vim.ui.select
      local select_called = false
      vim.ui.select = function(display_items, opts, on_choice)
        select_called = true
        on_choice(nil)
      end

      local callback_called = false

      select_mod.select({
        prompt = 'Select:',
        items = items,
        on_select = function(value)
          callback_called = true
        end,
      })

      assert.is_true(select_called)
      assert.is_false(callback_called)

      vim.ui.select = original_select
    end)

    describe('multi_select', function()
      it('should return array of values when multi_select is true', function()
        local items = {
          { value = 'a', display = 'Item A' },
          { value = 'b', display = 'Item B' },
          { value = 'c', display = 'Item C' },
        }

        local original_select = vim.ui.select
        vim.ui.select = function(display_items, opts, on_choice)
          -- Simulate multi-select: vim.ui.select doesn't support multi-select natively
          -- but our implementation should handle when Telescope returns multiple values
          -- For fallback, we simulate single selection
          on_choice(display_items[1])
        end

        local callback_value = nil

        select_mod.select({
          prompt = 'Select:',
          items = items,
          multi_select = true,
          on_select = function(value)
            callback_value = value
          end,
        })

        -- In vim.ui.select fallback, multi_select returns array with single item
        assert.is_not_nil(callback_value)
        assert.equals('table', type(callback_value))
        assert.equals(1, #callback_value)
        assert.equals('a', callback_value[1])

        vim.ui.select = original_select
      end)

      it('should return array when multi_select even with single selection', function()
        local items = {
          { value = { id = 100 }, display = 'Single' },
        }

        local original_select = vim.ui.select
        vim.ui.select = function(display_items, opts, on_choice)
          on_choice(display_items[1])
        end

        local callback_value = nil

        select_mod.select({
          prompt = 'Select:',
          items = items,
          multi_select = true,
          on_select = function(value)
            callback_value = value
          end,
        })

        assert.is_not_nil(callback_value)
        assert.equals('table', type(callback_value))
        assert.equals(1, #callback_value)
        assert.equals(100, callback_value[1].id)

        vim.ui.select = original_select
      end)
    end)
  end)
end)
