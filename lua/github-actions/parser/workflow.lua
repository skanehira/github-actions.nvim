---@class WorkflowParser
local M = {}

---@class Action
---@field owner string The owner of the action (e.g., "actions")
---@field repo string The repository name (e.g., "checkout")
---@field version? string The version/ref (e.g., "v3", "main")
---@field hash? string The commit hash (e.g., "8e5e7e5ab8b370d6c329ec480221332ada57f0ab")
---@field line number The 0-indexed line number in the buffer
---@field col number The 0-indexed column number in the buffer

---Parse a buffer and extract GitHub Actions
---@param bufnr number Buffer number to parse
---@return Action[] List of actions found in the buffer
function M.parse_buffer(bufnr)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  -- Check if treesitter parser is available
  local has_parser = pcall(vim.treesitter.get_parser, bufnr, 'yaml')
  if not has_parser then
    vim.notify('yaml treesitter parser not found', vim.log.levels.ERROR)
    return {}
  end

  local parser = vim.treesitter.get_parser(bufnr, 'yaml')
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Query for 'uses:' fields in workflow files
  local query = vim.treesitter.query.parse(
    'yaml',
    [[
    (block_mapping_pair
      key: (flow_node) @key (#eq? @key "uses")
      value: (flow_node) @value)
  ]]
  )

  local actions = {}
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    if name == 'value' then
      local text = vim.treesitter.get_node_text(node, bufnr)
      local row, col = node:range()

      -- Parse: owner/repo@version or owner/repo@hash # version
      -- Remove quotes if present
      text = text:gsub('^["\']', ''):gsub('["\']$', '')

      -- Get the full line to check for comments (treesitter doesn't include comments in node text)
      local line_text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

      -- Extract comment from the full line if present
      local comment
      local comment_start = line_text:find('#')
      if comment_start then
        comment = vim.trim(line_text:sub(comment_start + 1))
      end

      local owner, repo, ref = text:match('([^/]+)/([^@]+)@(.+)')
      if owner and repo and ref then
        local action = {
          line = row,
          col = col,
          owner = owner,
          repo = repo,
        }

        -- Determine if ref is a hash (40 hex characters) or version
        if ref:match('^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$') then
          action.hash = ref
          -- If there's a version in comment, use it
          if comment then
            action.version = comment
          end
        else
          action.version = ref
        end

        table.insert(actions, action)
      end
    end
  end

  return actions
end

return M
