local buffer_utils = require('github-actions.shared.buffer_utils')
local config = require('github-actions.config')

---@class LogsBuffer
local M = {}

-- Store buffer-specific data (bufnr -> { keymaps = {...} })
local buffer_data = {}

-- Cache for logs content (key: "run_id:job_id", value: {raw: string, formatted: string})
local logs_cache = {}

---Get buffer name for a log view
---@param title string Title for the logs
---@param run_id number The workflow run ID
---@return string bufname The buffer name
local function get_buffer_name(title, run_id)
  return string.format('GitHub Actions - Logs: %s (#%d)', title, run_id)
end

---Focus on window or create new split with buffer
---@param bufnr number Buffer number
---@param opts? table Options for window/buffer setup
---@return number winnr Window number
local function focus_or_create_window(bufnr, opts)
  -- Check if buffer is already displayed in a window
  local existing_winnr = buffer_utils.find_window_for_buffer(bufnr)
  if existing_winnr then
    -- Focus on existing window
    vim.api.nvim_set_current_win(existing_winnr)
    return existing_winnr
  end

  -- Get open_mode from opts or default to vsplit
  opts = opts or {}
  local open_mode = opts.open_mode or 'vsplit'

  -- Create new window according to open_mode
  if open_mode == 'tab' then
    vim.cmd('tabnew')
  elseif open_mode == 'vsplit' then
    vim.cmd('vsplit')
  elseif open_mode == 'split' then
    vim.cmd('split')
  elseif open_mode == 'current' then
    -- Stay in current window
  else
    -- Default to vsplit
    vim.cmd('vsplit')
  end

  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Set up folding options for the window
  local fold_by_default = opts.logs_fold_by_default

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
---@param opts? table Options for log buffer (should be pre-merged with defaults, includes logs_fold_by_default, open_mode, buflisted)
---@return number bufnr The buffer number
---@return number winnr The window number
---@return boolean is_existing Whether the buffer already existed
function M.create_buffer(title, run_id, opts)
  opts = opts or {}

  -- Get config defaults for buffer options
  local config_module = require('github-actions.config')
  local defaults = config_module.get_defaults()
  local buffer_config = defaults.history.buffer

  -- Extract buffer options with defaults
  local buflisted = opts.buflisted ~= nil and opts.buflisted or buffer_config.buflisted
  local open_mode = opts.open_mode or opts.buffer and opts.buffer.open_mode or 'vsplit'

  local bufname = get_buffer_name(title, run_id)

  -- Check if buffer already exists
  local existing_bufnr = buffer_utils.find_buffer_by_name(bufname)
  if existing_bufnr then
    -- Buffer exists, focus on it or create window for it
    local winnr = focus_or_create_window(
      existing_bufnr,
      { logs_fold_by_default = opts.logs_fold_by_default, open_mode = open_mode }
    )
    return existing_bufnr, winnr, true
  end

  -- Create new buffer (listed by default to avoid [No Name] buffers)
  local bufnr = vim.api.nvim_create_buf(buflisted, true)

  -- Try to set buffer name, handle collision error
  local success, err = pcall(vim.api.nvim_buf_set_name, bufnr, bufname)
  if not success then
    -- Buffer name already exists, delete the new buffer and find the existing one
    vim.api.nvim_buf_delete(bufnr, { force = true })
    existing_bufnr = buffer_utils.find_buffer_by_name(bufname)
    if existing_bufnr then
      local winnr = focus_or_create_window(
        existing_bufnr,
        { logs_fold_by_default = opts.logs_fold_by_default, open_mode = open_mode }
      )
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
  local winnr =
    focus_or_create_window(bufnr, { logs_fold_by_default = opts.logs_fold_by_default, open_mode = open_mode })

  -- Get keymaps from config (use custom if provided, otherwise defaults)
  local custom_keymaps = opts and opts.keymaps and opts.keymaps.logs or nil
  local keymaps = vim.tbl_deep_extend('force', defaults.history.keymaps.logs, custom_keymaps or {})

  -- Store buffer data
  buffer_data[bufnr] = {
    keymaps = keymaps,
  }

  -- Set up keymaps
  M.setup_keymaps(bufnr, keymaps)

  -- Clean up buffer data when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    callback = function()
      buffer_data[bufnr] = nil
    end,
  })

  return bufnr, winnr, false
end

---Setup buffer keymaps
---@param bufnr number The buffer number
---@param keymaps HistoryLogsKeymaps Keymap configuration
function M.setup_keymaps(bufnr, keymaps)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Close buffer
  vim.keymap.set('n', keymaps.close, function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end, opts)
end

---Get cached logs for a job
---@param run_id number The workflow run ID
---@param job_id number The job ID
---@return string|nil formatted_logs Cached formatted logs or nil if not found
---@return string|nil raw_logs Cached raw logs or nil if not found
function M.get_cached_logs(run_id, job_id)
  local cache_key = string.format('%d:%d', run_id, job_id)
  local cached = logs_cache[cache_key]
  if cached then
    return cached.formatted, cached.raw
  end
  return nil, nil
end

---Cache logs for a job
---@param run_id number The workflow run ID
---@param job_id number The job ID
---@param formatted_logs string The formatted logs content
---@param raw_logs string The raw logs content
function M.cache_logs(run_id, job_id, formatted_logs, raw_logs)
  local cache_key = string.format('%d:%d', run_id, job_id)
  logs_cache[cache_key] = {
    formatted = formatted_logs,
    raw = raw_logs,
  }
end

---Generate help text based on configured keymaps
---@param keymaps HistoryLogsKeymaps Keymap configuration
---@return string help_text Help text for the buffer
local function generate_help_text(keymaps)
  return string.format('Press %s to close, za to toggle fold, zo to open fold, zc to close fold', keymaps.close)
end

---Render logs in the buffer
---@param bufnr number The buffer number
---@param logs string The log content to display
function M.render(bufnr, logs)
  local lines = {}

  -- Add keymap help text at the top (using configured keymaps)
  local data = buffer_data[bufnr]
  local defaults = config.get_defaults()
  local keymaps = (data and data.keymaps) or defaults.history.keymaps.logs
  table.insert(lines, generate_help_text(keymaps))
  table.insert(lines, '')

  -- Add logs content
  if logs and logs ~= '' then
    local log_lines = vim.split(logs, '\n', { plain = true })
    for _, line in ipairs(log_lines) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, 'No logs available.')
  end

  -- Set buffer content
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

return M
