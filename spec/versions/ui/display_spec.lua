-- Test for version UI module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local helpers = require('spec.helpers.buffer_spec')

describe('display', function()
  ---@type Display
  local display = require('github-actions.versions.ui.display')
  ---@type number
  local test_bufnr = helpers.create_yaml_buffer([[
name: Test
jobs:
  test:
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v4
      - uses: actions/cache@v3
      - uses: actions/upload-artifact@v2
      - uses: actions/download-artifact@v2
]])

  after_each(function()
    display.clear_version_text(test_bufnr)
  end)

  describe('set_version_text', function()
    it('should set version text for latest version', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v4',
        latest_version = '4.0.0',
        is_latest = true,
      }

      display.set_version_text(test_bufnr, version_info)

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
      assert.equals('', icon_text, 'should have latest icon')

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

    it('should set version text for outdated version', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v3',
        latest_version = '4.0.0',
        is_latest = false,
      }

      display.set_version_text(test_bufnr, version_info)

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
      assert.equals('', icon_text, 'should have outdated icon')
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
        display.set_version_text(999999, version_info)
      end)
    end)

    it('should display error message when error field is present', function()
      local version_info = {
        line = 4,
        col = 12,
        error = 'Failed to fetch version',
      }

      display.set_version_text(test_bufnr, version_info)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.equals(1, #marks, 'should have one extmark')

      local mark = marks[1]
      local virt_text = mark[4].virt_text
      if not virt_text then
        error(vim.inspect(mark[4]))
      end

      -- Check for error icon
      local icon_text = virt_text[1][1]
      assert.equals('', icon_text, 'should have error icon')

      -- Check that error message is displayed
      local has_error_msg = false
      for _, chunk in ipairs(virt_text) do
        if chunk[1]:match('Failed to fetch version') then
          has_error_msg = true
          break
        end
      end
      assert.is_true(has_error_msg, 'should contain error message')
    end)
  end)

  describe('set_version_texts', function()
    it('should set multiple version texts', function()
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

      display.set_version_texts(test_bufnr, version_infos)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.equals(2, #marks, 'should have two extmarks')

      -- Verify lines
      assert.equals(4, marks[1][2], 'first mark should be on line 4')
      assert.equals(5, marks[2][2], 'second mark should be on line 5')
    end)

    it('should handle empty version_infos array', function()
      assert.has.no.errors(function()
        display.set_version_texts(test_bufnr, {})
      end)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})

      assert.equals(0, #marks, 'should have no extmarks')
    end)
  end)

  describe('clear_version_text', function()
    it('should clear all version text from buffer', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v3',
        latest_version = '4.0.0',
        is_latest = false,
      }

      display.set_version_text(test_bufnr, version_info)

      -- Verify mark exists
      local ns = display.get_namespace()
      local marks_before = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(1, #marks_before, 'should have one mark before clear')

      -- Clear
      display.clear_version_text(test_bufnr)

      -- Verify marks are cleared
      local marks_after = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(0, #marks_after, 'should have no marks after clear')
    end)

    it('should handle invalid buffer gracefully', function()
      assert.has.no.errors(function()
        display.clear_version_text(999999)
      end)
    end)
  end)

  describe('custom options', function()
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

      display.set_version_text(test_bufnr, version_info, opts)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      local virt_text = marks[1][4].virt_text
      if not virt_text then
        error(vim.inspect(marks))
      end

      -- Check for custom icon
      assert.equals('⚠', virt_text[1][1], 'should have custom outdated icon')
    end)

    it('should use custom highlight groups for icons', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v3',
        latest_version = '4.0.0',
        is_latest = false,
      }

      local opts = {
        highlight_icon_outdated = 'CustomOutdatedIcon',
        highlight_icon_latest = 'CustomLatestIcon',
        highlight_icon_error = 'CustomErrorIcon',
      }

      display.set_version_text(test_bufnr, version_info, opts)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      local virt_text = marks[1][4].virt_text
      if not virt_text then
        error(vim.inspect(marks))
      end

      -- Check for custom highlight group on icon (first chunk)
      local icon_highlight = virt_text[1][2]
      assert.equals('CustomOutdatedIcon', icon_highlight, 'should use custom outdated icon highlight')
    end)

    it('should use custom highlight groups for latest icon', function()
      local version_info = {
        line = 4,
        col = 12,
        current_version = 'v4',
        latest_version = '4.0.0',
        is_latest = true,
      }

      local opts = {
        highlight_icon_latest = 'CustomLatestIcon',
      }

      display.set_version_text(test_bufnr, version_info, opts)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      local virt_text = marks[1][4].virt_text
      if not virt_text then
        error(vim.inspect(marks))
      end

      -- Check for custom highlight group on icon (first chunk)
      local icon_highlight = virt_text[1][2]
      assert.equals('CustomLatestIcon', icon_highlight, 'should use custom latest icon highlight')
    end)

    it('should use custom highlight groups for error icon', function()
      local version_info = {
        line = 4,
        col = 12,
        error = 'Test error',
      }

      local opts = {
        highlight_icon_error = 'CustomErrorIcon',
      }

      display.set_version_text(test_bufnr, version_info, opts)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      local virt_text = marks[1][4].virt_text
      if not virt_text then
        error(vim.inspect(marks))
      end

      -- Check for custom highlight group on icon (first chunk)
      local icon_highlight = virt_text[1][2]
      assert.equals('CustomErrorIcon', icon_highlight, 'should use custom error icon highlight')
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

  describe('extmark lifecycle', function()
    it('should remove extmarks when action line is deleted', function()
      -- Initial setup: show version info on line 5
      local version_infos = {
        {
          line = 5,
          col = 12,
          current_version = 'v3',
          latest_version = 'v4.0.0',
          is_latest = false,
        },
      }

      display.show_versions(test_bufnr, version_infos)

      local ns = display.get_namespace()
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(1, #marks, 'should have one extmark initially')

      -- Simulate: action line is deleted, parser returns empty list
      -- In real usage, this is triggered by TextChanged/BufWritePost autocmds
      local empty_version_infos = {}
      display.show_versions(test_bufnr, empty_version_infos)

      -- Extmark should be removed because show_versions clears all extmarks first
      marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(0, #marks, 'should have no extmarks after action is deleted')
    end)

    it('should not leave extmarks on old line when action moves', function()
      -- Initial setup: action on line 5
      local version_infos_before = {
        {
          line = 5,
          col = 12,
          current_version = 'v3',
          latest_version = 'v4.0.0',
          is_latest = false,
        },
      }

      display.show_versions(test_bufnr, version_infos_before)

      local ns = display.get_namespace()
      local marks_before = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(1, #marks_before, 'should have one extmark initially')
      assert.equals(5, marks_before[1][2], 'extmark should be on line 5')

      -- Simulate: action moved to line 8
      -- In real usage, this is triggered by TextChanged/BufWritePost autocmds
      local version_infos_after = {
        {
          line = 8,
          col = 12,
          current_version = 'v3',
          latest_version = 'v4.0.0',
          is_latest = false,
        },
      }

      display.show_versions(test_bufnr, version_infos_after)

      -- Should have only one extmark on the new line
      -- show_versions clears all old extmarks and creates new ones
      local marks_after = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(1, #marks_after, 'should have one extmark after move')
      assert.equals(8, marks_after[1][2], 'extmark should be on line 8, not old line 5')
    end)
  end)
end)
