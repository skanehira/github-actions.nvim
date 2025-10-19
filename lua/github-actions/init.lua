---@class HistoryOptions
---@field highlight_colors? HistoryHighlightOptions Highlight color options for workflow history display (global setup)
---@field highlights? HistoryHighlights Highlight group names for workflow history display (per-buffer)
---@field icons? HistoryIcons Icon options for workflow history display
---@field logs_fold_by_default? boolean Whether to fold log groups by default (default: true)

---@class GithubActionsConfig
---@field actions? VirtualTextOptions Display options for GitHub Actions version checking
---@field history? HistoryOptions Options for workflow history display

---@class GithubActions
local M = {}

local checker = require('github-actions.workflow.checker')
local display = require('github-actions.display')
local highlights = require('github-actions.lib.highlights')
local git = require('github-actions.lib.git')
local input = require('github-actions.workflow.input')
local formatter = require('github-actions.history.ui.formatter')

---Current configuration
---@type GithubActionsConfig
local config = {}

---Setup the plugin with user configuration
---@param opts? GithubActionsConfig User configuration
function M.setup(opts)
  opts = opts or {}

  -- Setup highlight groups with custom history highlight colors if provided
  local history_highlight_colors = opts.history and opts.history.highlight_colors or nil
  highlights.setup(history_highlight_colors)

  -- Build default configuration (must be done here to get current default_options)
  local default_config = {
    actions = vim.deepcopy(display.default_options),
    history = vim.deepcopy(formatter.default_options),
  }

  -- Merge user config with defaults
  config = vim.tbl_deep_extend('force', default_config, opts)
end

---Get current configuration
---@return GithubActionsConfig config Current configuration
function M.get_config()
  return config
end

---Check and update version information for current buffer
function M.check_versions()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Business logic: check versions
  checker.check_versions(bufnr, function(version_infos, error)
    -- Error handling
    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    -- UI: display results
    display.show_versions(bufnr, version_infos, config.actions)
  end)
end

---Handle workflow dispatch result
---@param workflow_file string Workflow filename
---@param selected_branch string Selected branch
---@param success boolean Dispatch success status
---@param dispatch_err string|nil Dispatch error message
local function handle_dispatch_result(workflow_file, selected_branch, success, dispatch_err)
  vim.schedule(function()
    if success then
      local msg = string.format('Workflow "%s" dispatched successfully on branch "%s"', workflow_file, selected_branch)
      vim.notify(msg, vim.log.levels.INFO)
    else
      vim.notify('Failed to dispatch workflow: ' .. (dispatch_err or 'unknown error'), vim.log.levels.ERROR)
    end
  end)
end

---Collect inputs and dispatch workflow
---@param workflow_file string Workflow filename
---@param selected_branch string Selected branch
---@param workflow_dispatch_inputs WorkflowDispatchInput[] Workflow dispatch inputs
local function collect_inputs_and_dispatch(workflow_file, selected_branch, workflow_dispatch_inputs)
  local github = require('github-actions.github')

  input.collect_inputs(workflow_dispatch_inputs, {
    on_success = function(input_values)
      ---@diagnostic disable-next-line: param-type-mismatch
      github.dispatch_workflow(workflow_file, selected_branch, input_values, function(success, dispatch_err)
        handle_dispatch_result(workflow_file, selected_branch, success, dispatch_err)
      end)
    end,
    on_error = function(err)
      vim.notify(err, vim.log.levels.ERROR)
    end,
  })
end

---Handle branch selection
---@param workflow_file string Workflow filename
---@param workflow_dispatch_inputs WorkflowDispatchInput[] Workflow dispatch inputs
---@param selected_branch string|nil Selected branch
local function handle_branch_selection(workflow_file, workflow_dispatch_inputs, selected_branch)
  vim.schedule(function()
    if not selected_branch then
      return
    end
    collect_inputs_and_dispatch(workflow_file, selected_branch, workflow_dispatch_inputs)
  end)
end

---Dispatch the workflow in the current buffer
function M.dispatch_workflow()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = require('github-actions.workflow.parser')

  -- Get workflow filename
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local workflow_file = vim.fn.fnamemodify(filepath, ':t')

  -- Parse workflow_dispatch configuration
  local workflow_dispatch = parser.parse_workflow_dispatch(bufnr)
  if not workflow_dispatch then
    vim.notify('This workflow does not support workflow_dispatch', vim.log.levels.ERROR)
    return
  end

  -- Get available branches
  local branches = git.get_branches()
  if #branches == 0 then
    vim.notify('Failed to get git branches', vim.log.levels.ERROR)
    return
  end

  -- Ask user to select branch
  vim.ui.select(branches, {
    prompt = 'Select branch to run workflow on:',
  }, function(selected_branch)
    handle_branch_selection(workflow_file, workflow_dispatch.inputs, selected_branch)
  end)
end

return M
