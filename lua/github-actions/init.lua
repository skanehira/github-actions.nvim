---@class GithubActionsConfig
---@field actions? VirtualTextOptions Display options for GitHub Actions version checking

---@class GithubActions
local M = {}

local checker = require('github-actions.workflow.checker')
local display = require('github-actions.display')
local highlights = require('github-actions.lib.highlights')
local git = require('github-actions.lib.git')
local input = require('github-actions.workflow.input')

---Current configuration
---@type GithubActionsConfig
local config = {}

---Setup the plugin with user configuration
---@param opts? GithubActionsConfig User configuration
function M.setup(opts)
  -- Setup highlight groups
  highlights.setup()

  -- Build default configuration (must be done here to get current default_options)
  local default_config = {
    actions = vim.deepcopy(display.default_options),
  }

  -- Merge user config with defaults
  config = vim.tbl_deep_extend('force', default_config, opts or {})
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

---Dispatch the workflow in the current buffer
function M.dispatch_workflow()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = require('github-actions.workflow.parser')
  local github = require('github-actions.github')

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
    vim.schedule(function()
      if not selected_branch then
        return
      end

      -- Collect input values and dispatch workflow
      input.collect_inputs(workflow_dispatch.inputs, {
        on_success = function(input_values)
          -- Dispatch workflow with collected inputs
          ---@diagnostic disable-next-line: param-type-mismatch
          github.dispatch_workflow(workflow_file, selected_branch, input_values, function(success, dispatch_err)
            vim.schedule(function()
              if success then
                local msg =
                  string.format('Workflow "%s" dispatched successfully on branch "%s"', workflow_file, selected_branch)
                vim.notify(msg, vim.log.levels.INFO)
              else
                vim.notify('Failed to dispatch workflow: ' .. (dispatch_err or 'unknown error'), vim.log.levels.ERROR)
              end
            end)
          end)
        end,
        on_error = function(err)
          vim.notify(err, vim.log.levels.ERROR)
        end,
      })
    end)
  end)
end

return M
