local M = {}

---Check if the given path is a GitHub Actions workflow file
---@param path string File path
---@return boolean
function M.is_workflow_file(path)
  return path:match('%.github/workflows/[^/]+%.ya?ml$') ~= nil
end

---Extract workflow name from YAML content using treesitter (the `name:` field)
---@param bufnr number Buffer number
---@return string|nil workflow_name The workflow name, or nil if not found
function M.get_workflow_name(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, 'yaml')
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local root = tree:root()

  -- Query to find the top-level "name" field
  local query = vim.treesitter.query.parse(
    'yaml',
    [[
    (block_mapping_pair
      key: (flow_node) @key (#eq? @key "name")
      value: (flow_node) @value)
    ]]
  )

  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    if name == 'value' then
      local text = vim.treesitter.get_node_text(node, bufnr)
      -- Remove quotes if present
      local cleaned = text:gsub('^["\']', ''):gsub('["\']$', '')
      return cleaned
    end
  end

  return nil
end

---Find .github/workflows directory by traversing up from start_dir to home directory
---@param start_dir string Starting directory path
---@return string|nil workflows_dir The .github/workflows directory path, or nil if not found
function M.find_workflows_dir_upwards(start_dir)
  local home_dir = vim.fn.expand('~')
  local current_dir = start_dir

  while true do
    local workflows_dir = current_dir .. '/.github/workflows'
    if vim.fn.isdirectory(workflows_dir) == 1 then
      return workflows_dir
    end

    -- Stop if we've reached home directory
    if current_dir == home_dir then
      break
    end

    -- Move up to parent directory
    local parent_dir = vim.fn.fnamemodify(current_dir, ':h')

    -- Stop if we can't go further up (reached root or same directory)
    if parent_dir == current_dir then
      break
    end

    current_dir = parent_dir
  end

  return nil
end

---Find all workflow files in the current project
---@return string[] workflow_files List of workflow file paths relative to cwd
function M.find_workflow_files()
  local git = require('github-actions.lib.git')
  local cwd = vim.fn.getcwd()
  local workflows_dir

  -- Check if in a git repository
  local git_root = git.get_git_root()
  if git_root then
    -- Use git root
    workflows_dir = git_root .. '/.github/workflows'
  else
    -- Search upwards from cwd
    workflows_dir = M.find_workflows_dir_upwards(cwd)
  end

  -- Return empty list if workflows directory not found
  if not workflows_dir or vim.fn.isdirectory(workflows_dir) == 0 then
    return {}
  end

  -- Find all YAML files in workflows directory
  local files = vim.fn.glob(workflows_dir .. '/*.yml', false, true)
  local yaml_files = vim.fn.glob(workflows_dir .. '/*.yaml', false, true)

  -- Combine and convert to relative paths
  local all_files = vim.list_extend(files, yaml_files)
  local relative_files = {}

  for _, file in ipairs(all_files) do
    -- Convert absolute path to relative path
    local relative = file:gsub('^' .. vim.pesc(cwd) .. '/', '')
    table.insert(relative_files, relative)
  end

  return relative_files
end

return M
