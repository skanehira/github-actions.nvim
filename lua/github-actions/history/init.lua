local detector = require('github-actions.workflow.detector')
local history = require('github-actions.workflow.history')
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

---Show workflow run history for the current buffer
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@param custom_icons? HistoryIcons Custom icon configuration
function M.show_history(bufnr, custom_icons)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Validate workflow buffer
  local valid, error_msg = validate_workflow_buffer(bufnr)
  if not valid then
    vim.notify(error_msg, vim.log.levels.ERROR)
    return
  end

  -- Extract workflow filename
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local workflow_file = extract_workflow_filename(bufname)

  -- This should never be nil due to validate_workflow_buffer, but add assertion for safety
  assert(workflow_file, 'workflow_file should not be nil after validation')

  -- Fetch and display runs
  history.fetch_runs(workflow_file, function(runs, err)
    if err then
      vim.notify('Failed to fetch workflow runs: ' .. err, vim.log.levels.ERROR)
      return
    end

    if not runs then
      vim.notify('No runs data returned', vim.log.levels.ERROR)
      return
    end

    local hist_bufnr, _ = runs_buffer.create_buffer(workflow_file)
    runs_buffer.render(hist_bufnr, runs, custom_icons)
  end)
end

return M
