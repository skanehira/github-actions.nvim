local picker = require('github-actions.shared.picker')
local history = require('github-actions.history.api')
local runs_buffer = require('github-actions.history.ui.runs_buffer')

local M = {}

---Show workflow run history for a specific workflow file
---@param workflow_filepath string Workflow file path (absolute or relative)
---@param custom_icons? HistoryIcons Custom icon configuration
---@param custom_highlights? HistoryHighlights Custom highlight configuration
---@param custom_keymaps? HistoryKeymaps Custom keymap configuration
---@param buffer_config? HistoryBufferOptions Buffer display configuration
local function show_history_for_file(workflow_filepath, custom_icons, custom_highlights, custom_keymaps, buffer_config)
  -- Extract filename from path
  local workflow_file = workflow_filepath:match('[^/]+%.ya?ml$')

  -- Create buffer first and show loading message
  local opts = {
    custom_keymaps = custom_keymaps and custom_keymaps.list or nil,
    open_mode = buffer_config and buffer_config.history and buffer_config.history.open_mode or nil,
    buflisted = buffer_config and buffer_config.history and buffer_config.history.buflisted or nil,
  }
  local hist_bufnr, _ = runs_buffer.create_buffer(workflow_file, workflow_filepath, opts)
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
---Displays a workflow file selector (default) or branch/PR picker (when pr_mode=true)
---@param history_config? HistoryOptions History configuration
function M.show_history(history_config)
  history_config = history_config or {}

  -- If pr_mode is enabled, delegate to pr.init
  if history_config.pr_mode then
    local pr_init = require('github-actions.pr.init')
    pr_init.show_pr_history(history_config)
    return
  end

  local custom_icons = history_config.icons
  local custom_highlights = history_config.highlights
  local custom_keymaps = history_config.keymaps
  local buffer_config = history_config.buffer

  -- Default: show workflow file selector
  picker.select_workflow_files({
    prompt = 'Select workflow file(s)',
    on_select = function(selected_paths)
      -- Multiple selection: open all in new tabs
      for _, filepath in ipairs(selected_paths) do
        show_history_for_file(filepath, custom_icons, custom_highlights, custom_keymaps, buffer_config)
      end
    end,
  })
end

return M
