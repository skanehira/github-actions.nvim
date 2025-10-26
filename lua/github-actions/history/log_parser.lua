---@class LogParser
local M = {}

---Parse gh CLI log output format
---The format is: <job-name>\t<step-name>\t<timestamp> <log-line>
---@param raw_logs string Raw log output from gh CLI
---@param opts? {strip_ansi?: boolean} Options for parsing (default: strip_ansi = true)
---@return string formatted Formatted log output with just timestamp and content
function M.parse(raw_logs, opts)
  if not raw_logs or raw_logs == '' then
    return ''
  end

  opts = opts or {}
  local strip_ansi = opts.strip_ansi == nil and true or opts.strip_ansi

  local lines = vim.split(raw_logs, '\n', { plain = true })
  local formatted_lines = {}

  for _, line in ipairs(lines) do
    if line ~= '' then
      -- Split by tab to extract fields
      -- Format: job-name\tstep-name\ttimestamp log-content
      local fields = vim.split(line, '\t', { plain = true })

      if #fields >= 3 then
        -- Extract timestamp and log content (everything after second tab)
        local timestamp_and_content = fields[3]

        -- Extract just the timestamp (ISO8601 format) and content
        -- Timestamp format: 2025-10-17T11:23:49.1573737Z
        local timestamp_pattern = '%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d+Z'
        local timestamp = timestamp_and_content:match(timestamp_pattern)

        if timestamp then
          -- Extract content after timestamp
          local content = timestamp_and_content:gsub(timestamp_pattern .. '%s*', '', 1)
          -- Format: [HH:MM:SS] content
          local time_only = timestamp:match('T(%d%d:%d%d:%d%d)')
          table.insert(formatted_lines, string.format('[%s] %s', time_only, content))
        else
          -- If no timestamp found, just use the content as-is
          table.insert(formatted_lines, timestamp_and_content)
        end
      else
        -- If format is unexpected, include the line as-is
        table.insert(formatted_lines, line)
      end
    end
  end

  local result = table.concat(formatted_lines, '\n')

  -- Strip ANSI escape sequences if requested
  if strip_ansi then
    -- Match various forms of ANSI escape sequences:
    -- \27[...m (octal), \x1b[...m (hex), or literal escape character
    -- Pattern: ESC [ <parameters> <letter>
    result = result:gsub('\27%[([%d;]*)m', '') -- Standard SGR sequences (color, style)
    result = result:gsub('\27%[([%d;]*)([A-Za-z])', '') -- Other CSI sequences (cursor movement, etc.)
    -- OSC sequences (Operating System Command): \27]...\07 or \27]...\27\
    result = result:gsub('\27%].-\007', '') -- OSC with BEL terminator
    result = result:gsub('\27%].-\27\\', '') -- OSC with ST terminator
  end

  return result
end

return M
