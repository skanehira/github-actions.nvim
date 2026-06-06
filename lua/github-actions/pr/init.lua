local pr_api = require('github-actions.pr.api')
local select = require('github-actions.shared.select')
local history_api = require('github-actions.history.api')
local runs_buffer = require('github-actions.history.ui.runs_buffer')

local M = {}

---Format branch display text
---@param branch_info BranchWithPR
---@return string display Display text
local function format_branch_display(branch_info)
  if branch_info.pr_number then
    return string.format('%s #%d', branch_info.branch, branch_info.pr_number)
  end
  return branch_info.branch
end

---Show workflow history for a specific branch
---@param branch string Branch name
---@param history_config? HistoryOptions History configuration
local function show_history_for_branch(branch, history_config)
  history_config = history_config or {}

  local custom_icons = history_config.icons
  local custom_highlights = history_config.highlights
  local custom_keymaps = history_config.keymaps
  local buffer_config = history_config.buffer

  local hist_buffer_cfg = buffer_config and buffer_config.history or {}
  local opts = {
    custom_keymaps = custom_keymaps and custom_keymaps.list or nil,
    branch = branch,
    open_mode = hist_buffer_cfg.open_mode,
    buflisted = hist_buffer_cfg.buflisted,
    window_options = hist_buffer_cfg.window_options,
  }
  local hist_bufnr, _ = runs_buffer.create_buffer(branch, nil, opts)
  runs_buffer.show_loading(hist_bufnr)

  history_api.fetch_runs_by_branch(branch, function(runs, err)
    vim.schedule(function()
      runs_buffer.handle_fetch_result(hist_bufnr, err, runs, custom_icons, custom_highlights)
    end)
  end)
end

---Show PR/branch workflow history
---Displays a picker with branches (and associated PRs) to select from
---@param history_config? HistoryOptions History configuration
function M.show_pr_history(history_config)
  local current_branch = pr_api.get_current_branch()

  pr_api.fetch_branches_with_prs(function(branches, err)
    vim.schedule(function()
      if err then
        vim.notify('[GitHub Actions] Failed to fetch branches: ' .. err, vim.log.levels.ERROR)
        return
      end

      if not branches or #branches == 0 then
        vim.notify('[GitHub Actions] No branches found', vim.log.levels.WARN)
        return
      end

      -- Convert to SelectItem format
      local items = {}
      for _, branch_info in ipairs(branches) do
        table.insert(items, {
          value = branch_info.branch,
          display = format_branch_display(branch_info),
          ordinal = branch_info.branch,
        })
      end

      select.select({
        prompt = 'Select branch:',
        items = items,
        default_text = current_branch,
        on_select = function(branch)
          show_history_for_branch(branch, history_config)
        end,
      })
    end)
  end)
end

return M
