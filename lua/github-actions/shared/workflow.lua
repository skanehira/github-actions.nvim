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

---Find all workflow files in the current project
---@return string[] workflow_files List of workflow file paths relative to cwd
function M.find_workflow_files()
  local cwd = vim.fn.getcwd()
  local workflows_dir = cwd .. '/.github/workflows'

  -- Check if workflows directory exists
  if vim.fn.isdirectory(workflows_dir) == 0 then
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
