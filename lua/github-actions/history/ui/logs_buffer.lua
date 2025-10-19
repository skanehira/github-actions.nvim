---@class LogsBuffer
local M = {}

---Create a new logs buffer and window
---@param title string Title for the logs (e.g., "build / Run tests")
---@param run_id number The workflow run ID
---@return number bufnr The buffer number
---@return number winnr The window number
function M.create_buffer(title, run_id)
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

  -- Add header
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  table.insert(lines, bufname)

  -- Add separator
  table.insert(lines, string.rep('━', 80))

  -- Add blank line
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

  -- Add blank line
  table.insert(lines, '')

  -- Add footer
  table.insert(lines, 'Press q to close')

  -- Set buffer content
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

return M
