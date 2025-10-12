---@class Semver
local M = {}

---Parse version string into parts array
---@param version_str string|nil Version string (e.g., "v3.5.1", "v3", "3.5")
---@return number[] parts Array of version parts (e.g., {3, 5, 1})
function M.parse(version_str)
  if not version_str or version_str == '' then
    return {}
  end

  -- Remove 'v' prefix if present
  local cleaned = version_str:gsub('^v', '')

  -- Extract only numeric parts (major.minor.patch)
  -- This handles versions like "3.5.1-beta" by stopping at non-numeric
  local parts = {}
  for num in cleaned:gmatch('%d+') do
    table.insert(parts, tonumber(num))
    if #parts >= 3 then
      break -- Only take major, minor, patch
    end
  end

  return parts
end

---Compare versions with appropriate depth
---Only compare the parts that are specified in current_version
---@param current_version string|nil Current version (e.g., "v3", "v3.5", "v3.5.1")
---@param latest_version string|nil Latest available version
---@return boolean is_latest True if current is up-to-date
function M.compare(current_version, latest_version)
  local curr_parts = M.parse(current_version)
  local latest_parts = M.parse(latest_version)

  -- If parsing failed, consider it outdated
  if #curr_parts == 0 or #latest_parts == 0 then
    return false
  end

  -- Compare only the depth of current version
  -- e.g., if current is "v3" (major only), only compare major
  local depth = #curr_parts

  for i = 1, depth do
    local curr = curr_parts[i] or 0 -- If current doesn't have this part, assume 0
    local latest = latest_parts[i] or 0 -- If latest doesn't have this part, assume 0

    if curr < latest then
      return false -- outdated
    elseif curr > latest then
      return true -- somehow newer (edge case)
    end
    -- Equal, continue to next part
  end

  return true -- All compared parts are equal or newer
end

return M
