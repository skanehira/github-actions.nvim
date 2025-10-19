---@class LogsBuffer
local M = {}

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

---Create a new logs buffer and window
---@param title string Title for the logs (e.g., "build / Run tests")
---@param run_id number The workflow run ID
---@param opts? table Options for log buffer (logs_fold_by_default: boolean)
---@return number bufnr The buffer number
---@return number winnr The window number
function M.create_buffer(title, run_id, opts)
  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer name
  local bufname = string.format('GitHub Actions - Logs: %s (#%d)', title, run_id)
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Set buffer options
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].filetype = 'github-actions-logs'
  vim.bo[bufnr].modifiable = false

  -- Set up folding for log groups
  opts = opts or {}
  local fold_by_default = opts.logs_fold_by_default == nil and true or opts.logs_fold_by_default

  vim.wo.foldmethod = 'expr'
  vim.wo.foldexpr = 'v:lua.require("github-actions.history.ui.logs_buffer").foldexpr(v:lnum)'
  vim.wo.foldtext = 'v:lua.require("github-actions.history.ui.logs_buffer").foldtext()'
  vim.wo.foldenable = true
  vim.wo.foldlevel = fold_by_default and 0 or 99 -- Fold by default if enabled

  -- Create window (vertical split)
  vim.cmd('vsplit')
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Set up keymaps
  M.setup_keymaps(bufnr)

  return bufnr, winnr
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
