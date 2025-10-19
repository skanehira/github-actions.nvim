local M = {}

local pattern = '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z'

-- Cache the timezone offset (difference between local time and UTC in seconds)
local timezone_offset

---Get the timezone offset in seconds
---@return number Offset in seconds (positive for timezones ahead of UTC, negative for behind)
local function get_timezone_offset()
  if timezone_offset then
    return timezone_offset
  end

  -- Get current time
  local now = os.time()
  -- Get UTC time components
  ---@type osdate
  local utc_date = os.date('!*t', now) --[[@as osdate]]
  -- Convert UTC components back to timestamp (will be interpreted as local time)
  local utc_as_local = os.time(utc_date)
  -- The difference is the timezone offset
  timezone_offset = os.difftime(now, utc_as_local)

  return timezone_offset
end

---Parse ISO 8601 UTC timestamp to unix timestamp
---@param timestamp string ISO 8601 UTC timestamp (e.g., "2025-10-19T12:00:00Z")
---@return number Unix timestamp
function M.parse_iso8601(timestamp)
  -- Remove milliseconds if present
  local cleaned = timestamp:gsub('%.[%d]+Z$', 'Z')

  -- Parse ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
  local year, month, day, hour, min, sec = cleaned:match(pattern)

  if not year then
    error('Invalid ISO 8601 timestamp: ' .. timestamp)
  end

  -- Convert to numbers (guaranteed to be non-nil after the check above)
  ---@type integer
  local year_num = assert(tonumber(year), 'year should be a number')
  ---@type integer
  local month_num = assert(tonumber(month), 'month should be a number')
  ---@type integer
  local day_num = assert(tonumber(day), 'day should be a number')
  ---@type integer
  local hour_num = assert(tonumber(hour), 'hour should be a number')
  ---@type integer
  local min_num = assert(tonumber(min), 'min should be a number')
  ---@type integer
  local sec_num = assert(tonumber(sec), 'sec should be a number')

  -- os.time() interprets the table as local time, so we need to adjust for UTC
  local utc_time = os.time({
    year = year_num,
    month = month_num,
    day = day_num,
    hour = hour_num,
    min = min_num,
    sec = sec_num,
    isdst = false,
  })

  -- Add the timezone offset to convert from "UTC interpreted as local" to actual UTC timestamp
  return utc_time + get_timezone_offset()
end

---Format relative time from ISO 8601 timestamp
---@param timestamp string ISO 8601 timestamp
---@param current_time? number Current time (for testing), defaults to os.time()
---@return string Formatted relative time (e.g., "2h ago", "3d ago")
function M.format_relative(timestamp, current_time)
  current_time = current_time or os.time()
  local past_time = M.parse_iso8601(timestamp)
  local diff = os.difftime(current_time, past_time)

  if diff < 5 then
    return 'just now'
  elseif diff < 60 then
    return string.format('%ds ago', math.floor(diff))
  elseif diff < 3600 then
    return string.format('%dm ago', math.floor(diff / 60))
  elseif diff < 86400 then
    return string.format('%dh ago', math.floor(diff / 3600))
  elseif diff < 604800 then
    return string.format('%dd ago', math.floor(diff / 86400))
  elseif diff < 2592000 then
    return string.format('%dw ago', math.floor(diff / 604800))
  elseif diff < 31536000 then
    return string.format('%dmo ago', math.floor(diff / 2592000))
  else
    return string.format('%dy ago', math.floor(diff / 31536000))
  end
end

---Format duration in seconds to human-readable format
---@param seconds number Duration in seconds
---@return string Formatted duration (e.g., "3m 24s", "1h 12m 34s")
function M.format_duration(seconds)
  if seconds == 0 then
    return '0s'
  end

  local hours = math.floor(seconds / 3600)
  local mins = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60

  if hours > 0 then
    return string.format('%dh %dm %ds', hours, mins, secs)
  elseif mins > 0 then
    return string.format('%dm %ds', mins, secs)
  else
    return string.format('%ds', secs)
  end
end

return M
