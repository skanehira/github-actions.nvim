-- Test for version UI module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local helpers = require('spec.helpers.buffer_spec')

describe('display', function()
  ---@type Display
  local display = require('github-actions.display')
  ---@type number
  local test_bufnr = helpers.create_yaml_buffer([[
name: Test
jobs:
  test:
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v4
]])

  after_each(function()
    display.clear_virtual_text(test_bufnr)
  end)

  describe('set_virtual_text', function()
    it('should set virtual text for latest version', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v4',
        latest_version = '4.0.0',
        is_latest = true,
      }

      display.set_virtual_text(test_bufnr, version_info)

      -- Get extmarks to verify virtual text was set
      local ns = display.get_namespace()
      -- marks structure: array of [id, row, col, details]
      -- Example: { { 1, 4, 0, { virt_text = {...}, ... } }, ... }
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.equals(1, #marks, 'should have one extmark')

      -- mark structure: [id, row, col, details]
      -- Example: { 1, 4, 0, { virt_text = { {"", "hl_group"}, {" ", "Comment"}, ... } } }
      local mark = marks[1]
      assert.equals(4, mark[2], 'extmark should be on line 4')

      -- details structure: { virt_text = array, virt_text_pos = string, priority = number, ... }
      local details = mark[4]
      if not details then
        error(vim.inspect(mark))
      end
      assert.is_not_nil(details.virt_text)

      -- virt_text structure: array of [text, highlight_group] tuples
      -- Example: { {"", "GitHubActionsIconLatest"}, {" ", "Comment"}, {"4.0.0", "GitHubActionsVersionLatest"} }
      local virt_text = details.virt_text
      if not virt_text then
        error(vim.inspect(details))
      end
      assert.is_true(#virt_text >= 2, 'should have at least icon and version')

      -- Check for icon (first element)
      -- virt_text[1] = {text, highlight_group}
      local icon_text = virt_text[1][1]
      assert.equals(' ', icon_text, 'should have latest icon')

      -- Find version text (should contain '4.0.0')
      local has_version = false
      for _, chunk in ipairs(virt_text) do
        -- chunk = {text, highlight_group}
        if chunk[1]:match('4%.0%.0') then
          has_version = true
          break
        end
      end
      assert.is_true(has_version, 'should contain version 4.0.0')
    end)

    it('should set virtual text for outdated version', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v3',
        latest_version = '4.0.0',
        is_latest = false,
      }

      display.set_virtual_text(test_bufnr, version_info)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.equals(1, #marks, 'should have one extmark')

      local mark = marks[1]
      local virt_text = mark[4].virt_text
      if not virt_text then
        error(vim.inspect(mark[4]))
      end

      -- Check for outdated icon
      local icon_text = virt_text[1][1]
      assert.equals(' ', icon_text, 'should have outdated icon')
    end)

    it('should handle invalid buffer gracefully', function()
      local version_info = {
        line = 0,
        col = 0,
        current_version = 'v1',
        latest_version = '2.0.0',
        is_latest = false,
      }

      -- Should not throw error with invalid buffer
      assert.has.no.errors(function()
        display.set_virtual_text(999999, version_info)
      end)
    end)
  end)

  describe('set_virtual_texts', function()
    it('should set multiple virtual texts', function()
      local version_infos = {
        {
          line = 4,
          col = 12,
          current_version = 'v3',
          latest_version = '4.0.0',
          is_latest = false,
        },
        {
          line = 5,
          col = 12,
          current_version = 'v4',
          latest_version = '4.0.0',
          is_latest = true,
        },
      }

      display.set_virtual_texts(test_bufnr, version_infos)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.equals(2, #marks, 'should have two extmarks')

      -- Verify lines
      assert.equals(4, marks[1][2], 'first mark should be on line 4')
      assert.equals(5, marks[2][2], 'second mark should be on line 5')
    end)

    it('should handle empty version_infos array', function()
      assert.has.no.errors(function()
        display.set_virtual_texts(test_bufnr, {})
      end)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})

      assert.equals(0, #marks, 'should have no extmarks')
    end)
  end)

  describe('clear_virtual_text', function()
    it('should clear all virtual text from buffer', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v3',
        latest_version = '4.0.0',
        is_latest = false,
      }

      display.set_virtual_text(test_bufnr, version_info)

      -- Verify mark exists
      local ns = display.get_namespace()
      local marks_before = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(1, #marks_before, 'should have one mark before clear')

      -- Clear
      display.clear_virtual_text(test_bufnr)

      -- Verify marks are cleared
      local marks_after = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(0, #marks_after, 'should have no marks after clear')
    end)

    it('should handle invalid buffer gracefully', function()
      assert.has.no.errors(function()
        display.clear_virtual_text(999999)
      end)
    end)
  end)

  describe('custom options', function()
    it('should use custom prefix and suffix', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v4',
        latest_version = '4.0.0',
        is_latest = true,
      }

      local opts = {
        prefix = '>>',
        suffix = '<<',
      }

      display.set_virtual_text(test_bufnr, version_info, opts)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      local virt_text = marks[1][4].virt_text
      if not virt_text then
        error(vim.inspect(marks))
      end

      -- Check for custom prefix
      local has_prefix = false
      for _, chunk in ipairs(virt_text) do
        if chunk[1] == '>>' then
          has_prefix = true
          break
        end
      end
      assert.is_true(has_prefix, 'should contain custom prefix')
    end)

    it('should use custom icons', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v3',
        latest_version = '4.0.0',
        is_latest = false,
      }

      local opts = {
        icons = {
          outdated = '⚠',
          latest = '✓',
        },
      }

      display.set_virtual_text(test_bufnr, version_info, opts)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      local virt_text = marks[1][4].virt_text
      if not virt_text then
        error(vim.inspect(marks))
      end

      -- Check for custom icon
      assert.equals('⚠', virt_text[1][1], 'should have custom outdated icon')
    end)
  end)

  describe('show_versions', function()
    it('should clear and display version infos', function()
      local version_infos = {
        {
          line = 0,
          col = 0,
          current_version = 'v3',
          latest_version = 'v4.0.0',
          is_latest = false,
        },
        {
          line = 1,
          col = 0,
          current_version = 'v4',
          latest_version = 'v4.0.0',
          is_latest = true,
        },
      }

      display.show_versions(test_bufnr, version_infos)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(2, #marks)
    end)

    it('should handle empty version infos', function()
      assert.has.no.errors(function()
        display.show_versions(test_bufnr, {})
      end)
    end)

    it('should handle invalid buffer gracefully', function()
      local version_infos = {
        {
          line = 0,
          col = 0,
          current_version = 'v3',
          latest_version = 'v4.0.0',
          is_latest = false,
        },
      }

      assert.has.no.errors(function()
        display.show_versions(999999, version_infos)
      end)
    end)
  end)
end)
