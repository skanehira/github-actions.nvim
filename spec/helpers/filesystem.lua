---@class FilesystemHelper
local M = {}

---@class CreateProjectOpts
---@field has_workflows_dir boolean Whether to create .github/workflows directory
---@field subdirs? string[] Optional subdirectories to create
---@field workflow_files? string[] Optional workflow file names to create (e.g., {'ci.yml', 'deploy.yaml'})
---@field is_git_repo? boolean Whether to initialize as a git repository

---Creates a temporary project directory structure
---@param opts CreateProjectOpts Options for project creation
---@return string temp_dir The path to the created temporary directory
function M.create_temp_project(opts)
  local temp_dir = vim.fn.tempname()

  -- Create base directory
  vim.fn.mkdir(temp_dir, 'p')

  -- Initialize as git repository if requested
  if opts.is_git_repo then
    vim.fn.system({ 'git', '-C', temp_dir, 'init' })
  end

  -- Create .github/workflows if requested
  if opts.has_workflows_dir then
    local workflows_dir = temp_dir .. '/.github/workflows'
    vim.fn.mkdir(workflows_dir, 'p')

    -- Create workflow files if specified
    if opts.workflow_files then
      for _, filename in ipairs(opts.workflow_files) do
        local file_path = workflows_dir .. '/' .. filename
        local file = io.open(file_path, 'w')
        if file then
          file:write('name: Test Workflow\non: [push]\njobs:\n  test:\n    runs-on: ubuntu-latest\n')
          file:close()
        end
      end
    end
  end

  -- Create additional subdirectories
  if opts.subdirs then
    for _, subdir in ipairs(opts.subdirs) do
      local full_path = temp_dir .. '/' .. subdir
      vim.fn.mkdir(full_path, 'p')
    end
  end

  return temp_dir
end

---Safely removes a temporary directory and all its contents
---@param path string The path to remove
function M.cleanup(path)
  if path and vim.fn.isdirectory(path) == 1 then
    vim.fn.delete(path, 'rf')
  end
end

return M
