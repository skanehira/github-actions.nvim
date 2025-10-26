---@class DispatchModule
local M = {}

local parser = require('github-actions.dispatch.parser')
local input = require('github-actions.dispatch.input')
local github = require('github-actions.shared.github')
local git = require('github-actions.lib.git')
local detector = require('github-actions.shared.workflow')

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
        vim.schedule(function()
          if success then
            vim.notify(
              string.format('Workflow "%s" dispatched successfully on branch "%s"', workflow_file, selected_branch),
              vim.log.levels.INFO
            )
          else
            vim.notify(string.format('Failed to dispatch workflow: %s', err or 'Unknown error'), vim.log.levels.ERROR)
          end
        end)
      end)
    end,
    on_error = function(err)
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR)
      end)
    end,
  })
end

---Dispatch workflow for a specific file
---@param workflow_filepath string Workflow file path (absolute or relative)
local function dispatch_workflow_for_file(workflow_filepath)
  -- Open the file temporarily to parse workflow_dispatch
  local bufnr = vim.fn.bufadd(workflow_filepath)
  vim.fn.bufload(bufnr)

  -- Get workflow filename
  local workflow_file = vim.fn.fnamemodify(workflow_filepath, ':t')

  -- Parse workflow_dispatch configuration
  local workflow_dispatch = parser.parse_workflow_dispatch(bufnr)
  if not workflow_dispatch then
    vim.notify(
      string.format('Workflow "%s" does not support workflow_dispatch', workflow_file),
      vim.log.levels.ERROR
    )
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

---Dispatch workflow with user interaction
---If current buffer is a workflow file, dispatch it.
---Otherwise, show a selector to choose a workflow file.
---@param bufnr number Buffer number
function M.dispatch_workflow(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Check if current buffer is a workflow file
  if detector.is_workflow_file(filepath) then
    dispatch_workflow_for_file(filepath)
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
  local filepath_map = {}
  for _, path in ipairs(workflow_files) do
    local filename = path:match('[^/]+%.ya?ml$')
    table.insert(filenames, filename)
    filepath_map[filename] = path
  end

  vim.ui.select(filenames, {
    prompt = 'Select workflow file:',
  }, function(selected)
    if not selected then
      return
    end
    local selected_path = filepath_map[selected]
    dispatch_workflow_for_file(selected_path)
  end)
end

return M
