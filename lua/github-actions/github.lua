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

---Check if gh command is available
---@return boolean available True if gh command exists
function M.is_available()
  local result = vim.fn.executable('gh')
  return result == 1
end

---Fetch latest release for an action from GitHub
---@param owner string Repository owner (e.g., "actions")
---@param repo string Repository name (e.g., "checkout")
---@param callback function Callback function(version, error)
function M.fetch_latest_release(owner, repo, callback)
  if not M.is_available() then
    callback(nil, 'gh command not found')
    return
  end

  local api_path = string.format('repos/%s/%s/releases/latest', owner, repo)

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

    local version = M.extract_version(data)
    if not version then
      callback(nil, 'Failed to extract version from response')
      return
    end

    callback(version, nil)
  end)
end

return M
