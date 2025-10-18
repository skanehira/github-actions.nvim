---@class Github
local M = {}

---Parse JSON response from gh CLI
---@param json_str string JSON string from gh CLI
---@return table|nil data Parsed data or nil on error
---@return string|nil error Error message if parsing failed
function M.parse_response(json_str)
  if not json_str or json_str == '' then
    return nil, 'Empty response'
  end

  local success, result = pcall(vim.json.decode, json_str)
  if not success then
    return nil, 'Failed to parse JSON: ' .. tostring(result)
  end

  return result, nil
end

---Extract version from release data
---@param data table|nil Parsed release data from GitHub API
---@return string|nil version The tag_name field (e.g., "v5.0.0") or nil
function M.extract_version(data)
  if not data or type(data) ~= 'table' then
    return nil
  end

  return data.tag_name
end

---Extract latest tag from tags array data
---@param data table|nil Parsed tags array data from GitHub API
---@return string|nil version The first tag name (e.g., "v1.0.1") or nil
function M.extract_latest_tag(data)
  if not data or type(data) ~= 'table' or #data == 0 then
    return nil
  end

  local first_tag = data[1]
  if not first_tag or type(first_tag) ~= 'table' then
    return nil
  end

  return first_tag.name
end

---Check if gh command is available
---@return boolean available True if gh command exists
function M.is_available()
  local result = vim.fn.executable('gh')
  return result == 1
end

---Fetch latest tag for an action from GitHub
---@param owner string Repository owner (e.g., "actions")
---@param repo string Repository name (e.g., "checkout")
---@param callback fun(version: string|nil, error: string|nil) Callback function with version string or error
function M.fetch_latest_tag(owner, repo, callback)
  if not M.is_available() then
    callback(nil, 'gh command not found')
    return
  end

  local api_path = string.format('repos/%s/%s/tags', owner, repo)

  vim.system({ 'gh', 'api', api_path }, {}, function(result)
    if result.code ~= 0 then
      callback(nil, 'gh API call failed: ' .. (result.stderr or 'unknown error'))
      return
    end

    local data, parse_err = M.parse_response(result.stdout)
    if parse_err then
      callback(nil, parse_err)
      return
    end

    local version = M.extract_latest_tag(data)
    if not version then
      callback(nil, 'Failed to extract version from response')
      return
    end

    callback(version, nil)
  end)
end

---Fetch latest release for an action from GitHub
---Falls back to tags if no release exists
---@param owner string Repository owner (e.g., "actions")
---@param repo string Repository name (e.g., "checkout")
---@param callback fun(version: string|nil, error: string|nil) Callback function with version string or error
function M.fetch_latest_release(owner, repo, callback)
  if not M.is_available() then
    callback(nil, 'gh command not found')
    return
  end

  local api_path = string.format('repos/%s/%s/releases/latest', owner, repo)

  vim.system({ 'gh', 'api', api_path }, {}, function(result)
    -- If release exists, use it
    if result.code == 0 then
      local data, parse_err = M.parse_response(result.stdout)
      if parse_err then
        callback(nil, parse_err)
        return
      end

      local version = M.extract_version(data)
      if not version then
        callback(nil, 'Failed to extract version from response')
        return
      end

      callback(version, nil)
      return
    end

    -- Fallback to tags if release doesn't exist
    M.fetch_latest_tag(owner, repo, callback)
  end)
end

---@class WorkflowInput
---@field name string Input parameter name
---@field value string Input parameter value

---Dispatch a workflow using gh CLI
---@param workflow_file string Workflow filename (e.g., "ci.yml")
---@param ref string Git ref to run the workflow on (branch, tag, or commit)
---@param inputs WorkflowInput[] Array of workflow inputs
---@param callback fun(success: boolean, error: string|nil) Callback function with success status and optional error
function M.dispatch_workflow(workflow_file, ref, inputs, callback)
  if not M.is_available() then
    callback(false, 'gh command not found')
    return
  end

  -- Build command: gh workflow run <workflow> --ref <ref> [-f key=value ...]
  local cmd = { 'gh', 'workflow', 'run', workflow_file, '--ref', ref }

  -- Add input parameters
  for _, input in ipairs(inputs) do
    table.insert(cmd, '-f')
    table.insert(cmd, input.name .. '=' .. input.value)
  end

  vim.system(cmd, {}, function(result)
    if result.code ~= 0 then
      callback(false, 'gh workflow run failed: ' .. (result.stderr or 'unknown error'))
      return
    end

    callback(true, nil)
  end)
end

return M
