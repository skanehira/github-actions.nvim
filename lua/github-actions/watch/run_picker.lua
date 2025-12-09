local select = require('github-actions.shared.select')

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
  -- Convert runs to SelectItem format
  local items = {}
  for _, run in ipairs(opts.runs) do
    table.insert(items, {
      value = run,
      display = M.format_run_entry(run, opts.icons),
    })
  end

  select.select({
    prompt = opts.prompt,
    items = items,
    on_select = opts.on_select,
  })
end

return M
