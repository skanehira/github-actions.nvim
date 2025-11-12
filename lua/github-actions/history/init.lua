local picker = require('github-actions.shared.picker')
local history = require('github-actions.history.api')
local runs_buffer = require('github-actions.history.ui.runs_buffer')

local M = {}

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
---Always displays a workflow file selector, allowing users to choose
---which workflow(s) to view history for.
---@param config? HistoryOptions History configuration
function M.show_history(config)
  config = config or {}

  local custom_icons = config.icons
  local custom_highlights = config.highlights

  -- Always show workflow file selector
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
