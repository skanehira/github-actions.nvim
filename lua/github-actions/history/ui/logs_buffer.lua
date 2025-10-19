---@class LogsBuffer
local M = {}

-- Cache for logs content (key: "run_id:job_id", value: logs string)
local logs_cache = {}

---Get buffer name for a log view
---@param title string Title for the logs
---@param run_id number The workflow run ID
---@return string bufname The buffer name
local function get_buffer_name(title, run_id)
  return string.format('GitHub Actions - Logs: %s (#%d)', title, run_id)
end

---Find buffer by name
---@param bufname string Buffer name to find
---@return number|nil bufnr Buffer number if found, nil otherwise
local function find_buffer_by_name(bufname)
  -- First try using vim.fn.bufnr which searches all buffers including hidden ones
  local bufnr = vim.fn.bufnr('^' .. vim.fn.escape(bufname, '^$.*[]~\\') .. '$')
  if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  -- Fallback: search through all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == bufname then
      return buf
    end
  end
  return nil
end

---Find window displaying a buffer
---@param bufnr number Buffer number
---@return number|nil winnr Window number if found, nil otherwise
local function find_window_for_buffer(bufnr)
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) == bufnr then
      return winnr
    end
  end
  return nil
end

---Focus on window or create new split with buffer
---@param bufnr number Buffer number
---@param opts? table Options for window/buffer setup
---@return number winnr Window number
local function focus_or_create_window(bufnr, opts)
  -- Check if buffer is already displayed in a window
  local existing_winnr = find_window_for_buffer(bufnr)
  if existing_winnr then
    -- Focus on existing window
    vim.api.nvim_set_current_win(existing_winnr)
    return existing_winnr
  end

  -- Create new window with vertical split
  vim.cmd('vsplit')
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Set up folding options for the window
  opts = opts or {}
  local fold_by_default = opts.logs_fold_by_default == nil and true or opts.logs_fold_by_default

  vim.wo.foldmethod = 'expr'
  vim.wo.foldexpr = 'v:lua.require("github-actions.history.ui.logs_buffer").foldexpr(v:lnum)'
  vim.wo.foldtext = 'v:lua.require("github-actions.history.ui.logs_buffer").foldtext()'
  vim.wo.foldenable = true
  vim.wo.foldlevel = fold_by_default and 0 or 99

  return winnr
end

---Fold expression for GitHub Actions log groups
---@param lnum number Line number
---@return string Fold level
function M.foldexpr(lnum)
  local line = vim.fn.getline(lnum)

  -- Start fold at ##[group]
  if line:match('%[%d%d:%d%d:%d%d%] ##%[group%]') then
    return '>1'
  end

  -- End fold at ##[endgroup]
  if line:match('%[%d%d:%d%d:%d%d%] ##%[endgroup%]') then
    return '<1'
  end

  -- Continue fold level from previous line
  return '='
end

---Custom fold text for GitHub Actions log groups
---@return string Fold text
function M.foldtext()
  local line = vim.fn.getline(vim.v.foldstart)
  -- Extract group title after ##[group]
  local title = line:match('%[%d%d:%d%d:%d%d%] ##%[group%](.*)') or 'Log Group'
  local line_count = vim.v.foldend - vim.v.foldstart + 1
  return string.format('▸ %s (%d lines)', title, line_count)
end

---Create or reuse a logs buffer and window
---@param title string Title for the logs (e.g., "build / Run tests")
---@param run_id number The workflow run ID
---@param opts? table Options for log buffer (logs_fold_by_default: boolean)
---@return number bufnr The buffer number
---@return number winnr The window number
---@return boolean is_existing Whether the buffer already existed
function M.create_buffer(title, run_id, opts)
  local bufname = get_buffer_name(title, run_id)

  -- Check if buffer already exists
  local existing_bufnr = find_buffer_by_name(bufname)
  if existing_bufnr then
    -- Buffer exists, focus on it or create window for it
    local winnr = focus_or_create_window(existing_bufnr, opts)
    return existing_bufnr, winnr, true
  end

  -- Create new buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Try to set buffer name, handle collision error
  local success, err = pcall(vim.api.nvim_buf_set_name, bufnr, bufname)
  if not success then
    -- Buffer name already exists, delete the new buffer and find the existing one
    vim.api.nvim_buf_delete(bufnr, { force = true })
    existing_bufnr = find_buffer_by_name(bufname)
    if existing_bufnr then
      local winnr = focus_or_create_window(existing_bufnr, opts)
      return existing_bufnr, winnr, true
    else
      -- This shouldn't happen, but handle it gracefully
      error(string.format('Failed to create or find buffer: %s', err))
    end
  end

  -- Set buffer options
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = 'hide' -- Changed from 'wipe' to 'hide' to preserve buffer
  vim.bo[bufnr].filetype = 'github-actions-logs'
  vim.bo[bufnr].modifiable = false

  -- Create window and set up folding
  local winnr = focus_or_create_window(bufnr, opts)

  -- Set up keymaps
  M.setup_keymaps(bufnr)

  return bufnr, winnr, false
end

---Setup buffer keymaps
---@param bufnr number The buffer number
function M.setup_keymaps(bufnr)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Close buffer with 'q'
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end, opts)
end

---Get cached logs for a job
---@param run_id number The workflow run ID
---@param job_id number The job ID
---@return string|nil logs Cached logs or nil if not found
function M.get_cached_logs(run_id, job_id)
  local cache_key = string.format('%d:%d', run_id, job_id)
  return logs_cache[cache_key]
end

---Cache logs for a job
---@param run_id number The workflow run ID
---@param job_id number The job ID
---@param logs string The logs content
function M.cache_logs(run_id, job_id, logs)
  local cache_key = string.format('%d:%d', run_id, job_id)
  logs_cache[cache_key] = logs
end

---Render logs in the buffer
---@param bufnr number The buffer number
---@param logs string The log content to display
function M.render(bufnr, logs)
  local lines = {}

  -- Add logs content
  if logs and logs ~= '' then
    local log_lines = vim.split(logs, '\n', { plain = true })
    for _, line in ipairs(log_lines) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, 'No logs available.')
  end

  -- Add blank line
  table.insert(lines, '')

  -- Add footer
  table.insert(lines, 'Press q to close, za to toggle fold, zo to open fold, zc to close fold')

  -- Set buffer content
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

return M
