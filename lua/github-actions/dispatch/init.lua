---@class DispatchModule
local M = {}

local parser = require('github-actions.dispatch.parser')
local input = require('github-actions.dispatch.input')
local github = require('github-actions.shared.github')
local git = require('github-actions.lib.git')

---Handle branch selection callback
---@param workflow_file string Workflow filename
---@param inputs table Workflow inputs configuration
---@param selected_branch string|nil Selected branch
local function handle_branch_selection(workflow_file, inputs, selected_branch)
  if not selected_branch then
    return
  end

  -- Collect inputs and dispatch
  input.collect_inputs(inputs, {
    on_success = function(collected_inputs)
      -- Dispatch workflow
      github.dispatch_workflow(workflow_file, selected_branch, collected_inputs, function(success, err)
        if success then
          vim.notify(
            string.format('Workflow "%s" dispatched successfully on branch "%s"', workflow_file, selected_branch),
            vim.log.levels.INFO
          )
        else
          vim.notify(string.format('Failed to dispatch workflow: %s', err or 'Unknown error'), vim.log.levels.ERROR)
        end
      end)
    end,
    on_error = function(err)
      vim.notify(err, vim.log.levels.ERROR)
    end,
  })
end

---Dispatch workflow with user interaction
---@param bufnr number Buffer number
function M.dispatch_workflow(bufnr)
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
