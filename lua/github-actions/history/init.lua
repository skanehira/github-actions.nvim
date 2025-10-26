local detector = require('github-actions.shared.workflow')
local history = require('github-actions.history.api')
local runs_buffer = require('github-actions.history.ui.runs_buffer')

local M = {}

---Extract workflow filename from buffer path
---@param bufname string Buffer name/path
---@return string|nil filename Workflow filename or nil if not found
local function extract_workflow_filename(bufname)
  return bufname:match('[^/]+%.ya?ml$')
end

---Validate that the buffer is a workflow file with a name
---@param bufnr number Buffer number
---@return boolean valid True if valid workflow file
---@return string|nil error_msg Error message if invalid
local function validate_workflow_buffer(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  if not detector.is_workflow_file(bufname) then
    return false, 'Not a GitHub Actions workflow file'
  end

  if not detector.get_workflow_name(bufnr) then
    return false, 'Could not find workflow name in file'
  end

  if not extract_workflow_filename(bufname) then
    return false, 'Could not extract workflow filename'
  end

  return true, nil
end

---Show workflow run history for a specific workflow file
---@param workflow_file string Workflow filename
---@param custom_icons? HistoryIcons Custom icon configuration
---@param custom_highlights? HistoryHighlights Custom highlight configuration
local function show_history_for_file(workflow_file, custom_icons, custom_highlights)
  history.fetch_runs(workflow_file, function(runs, err)
    if err then
      vim.notify('[GitHub Actions] Failed to fetch workflow runs: ' .. err, vim.log.levels.ERROR)
      return
    end

    if not runs then
      vim.notify('[GitHub Actions] No runs data returned', vim.log.levels.ERROR)
      return
    end

    local hist_bufnr, _ = runs_buffer.create_buffer(workflow_file)
    runs_buffer.render(hist_bufnr, runs, custom_icons, custom_highlights)
  end)
end

---Show workflow run history
---If current buffer is a workflow file, show its history.
---Otherwise, show a selector to choose a workflow file.
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@param custom_icons? HistoryIcons Custom icon configuration
---@param custom_highlights? HistoryHighlights Custom highlight configuration
function M.show_history(bufnr, custom_icons, custom_highlights)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if current buffer is a workflow file
  local valid, _ = validate_workflow_buffer(bufnr)
  if valid then
    -- Use current buffer's workflow file
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local workflow_file = extract_workflow_filename(bufname)
    show_history_for_file(workflow_file, custom_icons, custom_highlights)
    return
  end

  -- Current buffer is not a workflow file, show selector
  local workflow_files = detector.find_workflow_files()
  if #workflow_files == 0 then
    vim.notify('[GitHub Actions] No workflow files found in .github/workflows/', vim.log.levels.ERROR)
    return
  end

  -- Extract just the filenames for display
  local filenames = {}
  for _, path in ipairs(workflow_files) do
    local filename = path:match('[^/]+%.ya?ml$')
    table.insert(filenames, filename)
  end

  vim.ui.select(filenames, {
    prompt = 'Select workflow file:',
  }, function(selected)
    if not selected then
      return
    end
    show_history_for_file(selected, custom_icons, custom_highlights)
  end)
end

return M
