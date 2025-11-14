---@class RunPickerOptions
---@field prompt string Picker prompt text
---@field runs WatchableRun[] Array of workflow runs to select from
---@field icons HistoryIcons Status icon configuration
---@field on_select fun(run: WatchableRun) Callback when run is selected

local M = {}

---Format workflow run entry for display
---@param run WatchableRun Workflow run
---@param icons HistoryIcons Icon configuration
---@return string formatted_entry Formatted string "[icon] branch (#run_id)"
function M.format_run_entry(run, icons)
  local icon = icons[run.status] or icons.unknown or '?'
  return string.format('[%s] %s (#%d)', icon, run.headBranch, run.databaseId)
end

---Display workflow run selection picker
---@param opts RunPickerOptions Picker options
function M.select_run(opts)
  -- Format all runs for display
  local formatted_items = {}
  for _, run in ipairs(opts.runs) do
    table.insert(formatted_items, M.format_run_entry(run, opts.icons))
  end

  -- Try to use telescope for better UX
  local has_telescope, _ = pcall(require, 'telescope.builtin')
  local has_telescope_actions, telescope_actions = pcall(require, 'telescope.actions')
  local has_telescope_state, telescope_state = pcall(require, 'telescope.actions.state')

  if has_telescope and has_telescope_actions and has_telescope_state then
    -- Use telescope native picker
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values

    pickers
      .new({}, {
        prompt_title = opts.prompt,
        finder = finders.new_table({
          results = opts.runs,
          entry_maker = function(run)
            return {
              value = run,
              display = M.format_run_entry(run, opts.icons),
              ordinal = M.format_run_entry(run, opts.icons),
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
          telescope_actions.select_default:replace(function()
            local selection = telescope_state.get_selected_entry()
            telescope_actions.close(prompt_bufnr)

            if selection then
              opts.on_select(selection.value)
            end
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(formatted_items, {
      prompt = opts.prompt,
    }, function(selected)
      if not selected then
        return
      end

      -- Find the run corresponding to the selected formatted string
      for i, item in ipairs(formatted_items) do
        if item == selected then
          opts.on_select(opts.runs[i])
          return
        end
      end
    end)
  end
end

return M
