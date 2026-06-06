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

  local hist_buffer_cfg = buffer_config and buffer_config.history or {}
  local opts = {
    custom_keymaps = custom_keymaps and custom_keymaps.list or nil,
    open_mode = hist_buffer_cfg.open_mode,
    buflisted = hist_buffer_cfg.buflisted,
    window_options = hist_buffer_cfg.window_options,
  }
  local hist_bufnr, _ = runs_buffer.create_buffer(workflow_file, workflow_filepath, opts)
  runs_buffer.show_loading(hist_bufnr)

  history.fetch_runs(workflow_file, function(runs, err)
    vim.schedule(function()
      runs_buffer.handle_fetch_result(hist_bufnr, err, runs, custom_icons, custom_highlights)
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
