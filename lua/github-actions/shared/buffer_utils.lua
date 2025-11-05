---@class BufferUtils
local M = {}

---Find window displaying the specified buffer across all tab pages
---@param bufnr number Buffer number to find
---@return number|nil winid Window ID where buffer is displayed, or nil if not found
function M.find_window_for_buffer(bufnr)
  -- Search through all tab pages
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_get_buf(winid) == bufnr then
        return winid
      end
    end
  end
  return nil
end

---Find buffer by name
---@param bufname string Buffer name to find
---@return number|nil bufnr Buffer number if found, nil otherwise
function M.find_buffer_by_name(bufname)
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

---Focus on window or create new window with buffer
---@param bufnr number Buffer number
---@param opts? table Options: {split: "vertical"|"horizontal"|nil}
---@return number winnr Window number
function M.focus_or_create_window(bufnr, opts)
  opts = opts or {}

  -- Check if buffer is already displayed in a window (across all tabs)
  local existing_winid = M.find_window_for_buffer(bufnr)
  if existing_winid then
    -- Buffer is already visible, return the window (don't switch to it)
    return existing_winid
  end

  -- Buffer not displayed, create new window
  if opts.split == 'vertical' then
    vim.cmd('vsplit')
  elseif opts.split == 'horizontal' then
    vim.cmd('split')
  end
  -- If no split specified, use current window

  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  return winnr
end

return M
