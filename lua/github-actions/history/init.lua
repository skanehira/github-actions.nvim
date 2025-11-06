local detector = require('github-actions.shared.workflow')
local picker = require('github-actions.shared.picker')
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
---@param workflow_filepath string Workflow file path (absolute or relative)
---@param custom_icons? HistoryIcons Custom icon configuration
---@param custom_highlights? HistoryHighlights Custom highlight configuration
local function show_history_for_file(workflow_filepath, custom_icons, custom_highlights)
  -- Extract filename from path
  local workflow_file = workflow_filepath:match('[^/]+%.ya?ml$')

  -- Create buffer first and show loading message
  local hist_bufnr, _ = runs_buffer.create_buffer(workflow_file, true)
  runs_buffer.show_loading(hist_bufnr)

  -- Fetch runs in the background
  history.fetch_runs(workflow_file, function(runs, err)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(hist_bufnr) then
        return
      end

      if err then
        vim.notify('[GitHub Actions] Failed to fetch workflow runs: ' .. err, vim.log.levels.ERROR)
        -- Show error message in buffer
        vim.bo[hist_bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(hist_bufnr, 0, -1, false, { 'Failed to fetch workflow runs: ' .. err })
        vim.bo[hist_bufnr].modifiable = false
        return
      end

      if not runs then
        vim.notify('[GitHub Actions] No runs data returned', vim.log.levels.ERROR)
        -- Show error message in buffer
        vim.bo[hist_bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(hist_bufnr, 0, -1, false, { 'No runs data returned' })
        vim.bo[hist_bufnr].modifiable = false
        return
      end

      -- Render runs data in the buffer
      runs_buffer.render(hist_bufnr, runs, custom_icons, custom_highlights)
    end)
  end)
end

---Show workflow run history
---If current buffer is a workflow file, show its history.
---Otherwise, show a selector to choose a workflow file.
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@param config? HistoryOptions History configuration
function M.show_history(bufnr, config)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  config = config or {}

  local custom_icons = config.icons
  local custom_highlights = config.highlights

  -- Check if current buffer is a workflow file
  local valid, _ = validate_workflow_buffer(bufnr)
  if valid then
    -- Use current buffer's workflow file
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local workflow_file = extract_workflow_filename(bufname)
    if workflow_file then
      show_history_for_file(workflow_file, custom_icons, custom_highlights)
    end
    return
  end

  -- Current buffer is not a workflow file, show selector
  picker.select_workflow_files({
    prompt = 'Select workflow file(s)',
    on_select = function(selected_paths)
      -- Multiple selection: open all in new tabs
      for _, filepath in ipairs(selected_paths) do
        show_history_for_file(filepath, custom_icons, custom_highlights)
      end
    end,
  })
end

return M
