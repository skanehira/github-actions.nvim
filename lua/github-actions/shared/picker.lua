local detector = require('github-actions.shared.workflow')
local select = require('github-actions.shared.select')

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

  -- Convert workflow files to SelectItem format
  local items = {}
  for _, path in ipairs(workflow_files) do
    local filename = path:match('[^/]+%.ya?ml$')
    table.insert(items, {
      value = path,
      display = filename,
      path = path,
    })
  end

  -- Create previewer for file content
  local has_previewers, previewers = pcall(require, 'telescope.previewers')
  local previewer = has_previewers and previewers.vim_buffer_cat.new({}) or nil

  select.select({
    prompt = opts.prompt,
    items = items,
    multi_select = true,
    previewer = previewer,
    on_select = function(values)
      -- values is already an array of full paths
      opts.on_select(values)
    end,
  })
end

return M
