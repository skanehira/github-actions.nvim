---@class SelectItem
---@field value any Value to pass to callback when selected
---@field display string Display text for the item
---@field ordinal? string Text for searching/filtering (defaults to display)
---@field path? string File path for preview (optional)

---@class SelectOptions
---@field prompt string Prompt text to display
---@field items SelectItem[] Items to select from
---@field on_select fun(value: any|any[]) Callback when item(s) selected
---@field multi_select? boolean Enable multi-select mode (default: false)
---@field previewer? table Telescope previewer (optional)
---@field default_text? string Initial text in search input (Telescope only)

local M = {}

---Check if Telescope is available
---@return boolean has_telescope
---@return table|nil telescope_actions
---@return table|nil telescope_state
local function check_telescope()
  local has_telescope, _ = pcall(require, 'telescope.builtin')
  local has_telescope_actions, telescope_actions = pcall(require, 'telescope.actions')
  local has_telescope_state, telescope_state = pcall(require, 'telescope.actions.state')

  if has_telescope and has_telescope_actions and has_telescope_state then
    return true, telescope_actions, telescope_state
  end

  return false, nil, nil
end

---Create display items array from SelectItem array
---@param items SelectItem[]
---@return string[]
local function create_display_items(items)
  local display_items = {}
  for _, item in ipairs(items) do
    table.insert(display_items, item.display)
  end
  return display_items
end

---Find item by display text
---@param items SelectItem[]
---@param display string
---@return SelectItem|nil
local function find_item_by_display(items, display)
  for _, item in ipairs(items) do
    if item.display == display then
      return item
    end
  end
  return nil
end

---Display selection UI using Telescope or vim.ui.select fallback
---@param opts SelectOptions Options
function M.select(opts)
  local has_telescope, telescope_actions, telescope_state = check_telescope()

  if has_telescope then
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values

    local picker_opts = {
      prompt_title = opts.prompt,
      finder = finders.new_table({
        results = opts.items,
        entry_maker = function(item)
          return {
            value = item,
            display = item.display,
            ordinal = item.ordinal or item.display,
            path = item.path,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Add preview scrolling keymaps if previewer is used
        if opts.previewer then
          map('i', '<C-u>', telescope_actions.preview_scrolling_up)
          map('i', '<C-d>', telescope_actions.preview_scrolling_down)
          map('n', '<C-u>', telescope_actions.preview_scrolling_up)
          map('n', '<C-d>', telescope_actions.preview_scrolling_down)
        end

        telescope_actions.select_default:replace(function()
          local picker = telescope_state.get_current_picker(prompt_bufnr)

          telescope_actions.close(prompt_bufnr)

          if opts.multi_select then
            local selections = picker:get_multi_selection()

            -- If multi-selection is empty, use current selection
            if vim.tbl_isempty(selections) then
              local selection = telescope_state.get_selected_entry()
              if selection then
                opts.on_select({ selection.value.value })
              end
            else
              local values = {}
              for _, entry in ipairs(selections) do
                table.insert(values, entry.value.value)
              end
              opts.on_select(values)
            end
          else
            local selection = telescope_state.get_selected_entry()
            if selection then
              opts.on_select(selection.value.value)
            end
          end
        end)
        return true
      end,
    }

    if opts.previewer then
      picker_opts.previewer = opts.previewer
    end

    local telescope_config = {}
    if opts.default_text then
      telescope_config.default_text = opts.default_text
    end

    pickers.new(telescope_config, picker_opts):find()
  else
    -- Fallback to vim.ui.select
    local display_items = create_display_items(opts.items)

    vim.ui.select(display_items, {
      prompt = opts.prompt,
    }, function(selected)
      if not selected then
        return
      end

      local item = find_item_by_display(opts.items, selected)
      if not item then
        return
      end

      if opts.multi_select then
        opts.on_select({ item.value })
      else
        opts.on_select(item.value)
      end
    end)
  end
end

return M
