local detector = require('github-actions.shared.workflow')

local M = {}

---Options for workflow file picker
---@class PickerOptions
---@field prompt string Prompt text to display
---@field on_select function(selected: string[]) Callback with selected file path(s)

---Select workflow files using telescope or vim.ui.select
---@param opts PickerOptions Picker options
function M.select_workflow_files(opts)
  -- Get workflow files
  local workflow_files = detector.find_workflow_files()
  if #workflow_files == 0 then
    vim.notify('[GitHub Actions] No workflow files found in .github/workflows/', vim.log.levels.ERROR)
    return
  end

  -- Create display items and path mapping
  local items = {}
  local path_map = {}
  for _, path in ipairs(workflow_files) do
    local filename = path:match('[^/]+%.ya?ml$')
    table.insert(items, filename)
    path_map[filename] = path
  end

  -- Try to use telescope for multi-select support
  local has_telescope, _ = pcall(require, 'telescope.builtin')
  local has_telescope_actions, telescope_actions = pcall(require, 'telescope.actions')
  local has_telescope_state, telescope_state = pcall(require, 'telescope.actions.state')

  if has_telescope and has_telescope_actions and has_telescope_state then
    -- Use telescope native picker for multi-select support
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values

    pickers
      .new({}, {
        prompt_title = opts.prompt,
        finder = finders.new_table({
          results = items,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
          telescope_actions.select_default:replace(function()
            local picker = telescope_state.get_current_picker(prompt_bufnr)
            local selections = picker:get_multi_selection()

            telescope_actions.close(prompt_bufnr)

            -- If multi-selection is empty, use current selection
            if vim.tbl_isempty(selections) then
              local selection = telescope_state.get_selected_entry()
              if selection then
                -- Convert filename to full path
                local full_path = path_map[selection.value]
                opts.on_select({ full_path })
              end
            else
              -- Handle multi-selection
              local selected_paths = {}
              for _, entry in ipairs(selections) do
                -- Convert filename to full path
                local full_path = path_map[entry.value]
                table.insert(selected_paths, full_path)
              end
              opts.on_select(selected_paths)
            end
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(items, {
      prompt = opts.prompt,
    }, function(selected)
      if not selected then
        return
      end

      -- Handle both single selection (string) and multiple selection (table)
      local selected_items = type(selected) == 'table' and selected or { selected }

      -- Convert filenames to full paths
      local selected_paths = {}
      for _, item in ipairs(selected_items) do
        table.insert(selected_paths, path_map[item])
      end

      opts.on_select(selected_paths)
    end)
  end
end

return M
