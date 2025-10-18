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
function M.parse(bufnr)
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
  if parser == nil then
    return {}
  end
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Query for 'uses:' fields in workflow files
  -- Only match uses within steps (block_sequence under 'steps' key)
  local query = vim.treesitter.query.parse(
    'yaml',
    [[
    (block_mapping_pair
      key: (flow_node) @steps_key (#eq? @steps_key "steps")
      value: (block_node
        (block_sequence
          (block_sequence_item
            (block_node
              (block_mapping
                (block_mapping_pair
                  key: (flow_node) @key (#eq? @key "uses")
                  value: (flow_node) @value)
               )
              )
            )
          )
        )
      )
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
        if ref:match('^%x+$') and #ref == 40 then
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

---@class WorkflowDispatchInput
---@field name string Input parameter name
---@field description? string Input description
---@field required? boolean Whether the input is required
---@field default? string Default value
---@field type? string Input type (choice, string, boolean, etc.)
---@field options? string[] Available options for choice type

---@class WorkflowDispatchInfo
---@field inputs WorkflowDispatchInput[] Array of workflow inputs

---Helper function to get text from a flow_node, handling different scalar types
---@param node TSNode The flow_node
---@param bufnr number Buffer number
---@return string|nil text The node text without quotes, or nil
local function get_flow_node_value(node, bufnr)
  if not node or node:type() ~= 'flow_node' then
    return nil
  end

  -- Get the full text
  local text = vim.treesitter.get_node_text(node, bufnr)

  -- Remove surrounding quotes if present
  text = text:gsub('^["\']', ''):gsub('["\']$', '')

  return text
end

---Find the inputs mapping within workflow_dispatch
---@param node TSNode The workflow_dispatch node
---@param bufnr number Buffer number
---@return TSNode|nil inputs_node The inputs node or nil
local function find_inputs_node(node, bufnr)
  if node:type() == 'block_mapping' then
    for child in node:iter_children() do
      if child:type() == 'block_mapping_pair' then
        local key_node = child:child(0)
        if key_node and key_node:type() == 'flow_node' then
          local key = vim.treesitter.get_node_text(key_node, bufnr)
          if key == 'inputs' then
            -- Found inputs! Return the value node
            local value_node = child:child(2) -- Skip the ':' separator
            return value_node
          end
        end
      end
    end
  end
  return nil
end

---Parse input options from a block_sequence node
---@param prop_value_node TSNode The property value node
---@param bufnr number Buffer number
---@return string[] options List of option values
local function parse_input_options(prop_value_node, bufnr)
  local options = {}
  if prop_value_node:type() == 'block_node' then
    local seq = prop_value_node:child(0)
    if seq and seq:type() == 'block_sequence' then
      for seq_item in seq:iter_children() do
        if seq_item:type() == 'block_sequence_item' then
          -- Get the flow_node (skip the '-')
          local option_node = seq_item:child(1)
          if option_node then
            local option = get_flow_node_value(option_node, bufnr)
            if option then
              table.insert(options, option)
            end
          end
        end
      end
    end
  end
  return options
end

---Parse input properties from a block_mapping node
---@param props_mapping TSNode The properties mapping node
---@param bufnr number Buffer number
---@return table input_props Table of input properties
local function parse_input_properties(props_mapping, bufnr)
  local input_props = {}

  for prop_pair in props_mapping:iter_children() do
    if prop_pair:type() == 'block_mapping_pair' then
      local prop_key_node = prop_pair:child(0)
      local prop_value_node = prop_pair:child(2) -- Skip ':'

      if prop_key_node and prop_value_node then
        local prop_key = vim.treesitter.get_node_text(prop_key_node, bufnr)

        if prop_key == 'description' or prop_key == 'default' or prop_key == 'type' then
          input_props[prop_key] = get_flow_node_value(prop_value_node, bufnr)
        elseif prop_key == 'required' then
          local value = get_flow_node_value(prop_value_node, bufnr)
          input_props.required = value == 'true'
        elseif prop_key == 'options' then
          input_props.options = parse_input_options(prop_value_node, bufnr)
        end
      end
    end
  end

  return input_props
end

---Parse all inputs from the inputs mapping node
---@param inputs_mapping TSNode The inputs mapping node
---@param bufnr number Buffer number
---@return WorkflowDispatchInput[] inputs List of parsed inputs
local function parse_inputs(inputs_mapping, bufnr)
  local inputs = {}

  for input_pair in inputs_mapping:iter_children() do
    if input_pair:type() == 'block_mapping_pair' then
      -- Get input name
      local input_name_node = input_pair:child(0)
      if input_name_node and input_name_node:type() == 'flow_node' then
        local input_name = vim.treesitter.get_node_text(input_name_node, bufnr)

        local input = { name = input_name }

        -- Get input properties
        local input_props_node = input_pair:child(2) -- Skip ':'
        if input_props_node and input_props_node:type() == 'block_node' then
          local props_mapping = input_props_node:child(0)
          if props_mapping and props_mapping:type() == 'block_mapping' then
            local props = parse_input_properties(props_mapping, bufnr)
            -- Merge properties into input table
            for k, v in pairs(props) do
              input[k] = v
            end
          end
        end

        table.insert(inputs, input)
      end
    end
  end

  return inputs
end

---Find workflow_dispatch node using treesitter query
---@param root TSNode Root node
---@param bufnr number Buffer number
---@return TSNode|nil workflow_dispatch_node The workflow_dispatch value node or nil
local function find_workflow_dispatch_node(root, bufnr)
  -- Query to find workflow_dispatch node with value
  local workflow_dispatch_query = vim.treesitter.query.parse(
    'yaml',
    [[
    (block_mapping_pair
      key: (flow_node) @on_key (#eq? @on_key "on")
      value: (block_node
        (block_mapping
          (block_mapping_pair
            key: (flow_node) @wd_key (#eq? @wd_key "workflow_dispatch")
            value: (block_node) @wd_value
          )
        )
      )
    )
  ]]
  )

  for id, node in workflow_dispatch_query:iter_captures(root, bufnr, 0, -1) do
    local name = workflow_dispatch_query.captures[id]
    if name == 'wd_value' then
      return node
    end
  end

  return nil
end

---Check if workflow_dispatch exists without a value (empty)
---@param root TSNode Root node
---@param bufnr number Buffer number
---@return boolean has_empty_workflow_dispatch True if empty workflow_dispatch exists
local function has_empty_workflow_dispatch(root, bufnr)
  local empty_query = vim.treesitter.query.parse(
    'yaml',
    [[
    (block_mapping_pair
      key: (flow_node) @on_key (#eq? @on_key "on")
      value: (block_node
        (block_mapping
          (block_mapping_pair
            key: (flow_node) @wd_key (#eq? @wd_key "workflow_dispatch")
          )
        )
      )
    )
  ]]
  )

  for id, _ in empty_query:iter_captures(root, bufnr, 0, -1) do
    local name = empty_query.captures[id]
    if name == 'wd_key' then
      return true
    end
  end

  return false
end

---Parse workflow_dispatch configuration using treesitter
---@param bufnr number Buffer number to parse
---@return WorkflowDispatchInfo|nil Dispatch info or nil if workflow_dispatch not found
function M.parse_workflow_dispatch(bufnr)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  -- Check if treesitter parser is available
  local has_parser = pcall(vim.treesitter.get_parser, bufnr, 'yaml')
  if not has_parser then
    return nil
  end

  local parser = vim.treesitter.get_parser(bufnr, 'yaml')
  if parser == nil then
    return nil
  end
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Find workflow_dispatch node
  local workflow_dispatch_node = find_workflow_dispatch_node(root, bufnr)

  -- If query didn't match, check if workflow_dispatch exists without a value (empty)
  if not workflow_dispatch_node then
    if has_empty_workflow_dispatch(root, bufnr) then
      return { inputs = {} }
    end
    return nil
  end

  -- Extract inputs from workflow_dispatch node
  local inputs_node = nil
  local child = workflow_dispatch_node:child(0)
  if child then
    inputs_node = find_inputs_node(child, bufnr)
  end

  if not inputs_node then
    -- workflow_dispatch exists but no inputs
    return { inputs = {} }
  end

  -- Parse inputs
  local inputs_mapping = inputs_node:child(0) -- Get the block_mapping
  if not inputs_mapping or inputs_mapping:type() ~= 'block_mapping' then
    return { inputs = {} }
  end

  local inputs = parse_inputs(inputs_mapping, bufnr)

  return { inputs = inputs }
end

return M
