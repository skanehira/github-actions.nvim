---@class TerminalOpenOptions
---@field window_options? (FloatWindowOptions|table<string, any>) Float geometry or window-local options
---@field title? string Window title (float mode only)
---@field on_exit? fun() Callback invoked (via vim.schedule) when terminal exits

---Closes a terminal window and its buffer
---@param winid integer
---@param bufnr? number Buffer number (captured before win close to avoid focus shift)
local function close_terminal_buffer_job(winid, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end

  -- Schedule buffer deletion to avoid E937 when called from TermClose autocommand
  -- (Neovim refuses to delete a buffer while its own TermClose is running)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
    end)
  end
end

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

---Open a floating window with consistent defaults
---@param bufnr number Buffer number to display
---@param opts? table Options: width, height, row, col, title (default: 80% of editor, centered)
---@return number winid Window ID
function M.open_float_window(bufnr, opts)
  opts = opts or {}
  local columns = (vim.o.columns and vim.o.columns > 0) and vim.o.columns or 80
  local lines = (vim.o.lines and vim.o.lines > 0) and vim.o.lines or 24
  local width = opts.width or math.floor(columns * 0.8)
  local height = opts.height or math.floor(lines * 0.8)

  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    row = opts.row or math.floor((lines - height) / 2),
    col = opts.col or math.floor((columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
  }
  if opts.title then
    win_config.title = opts.title
    if vim.fn.has('nvim-0.10') == 1 then
      win_config.title_pos = 'center'
    end
  end

  local winid = vim.api.nvim_open_win(bufnr, true, win_config)
  for key, value in pairs(opts) do
    pcall(function()
      vim.wo[winid][key] = value
    end)
  end
  return winid
end

---Open a terminal in the specified mode (float, tab, vsplit, split, current)
---@param mode string Open mode: "tab", "vsplit", "split", "current", or "float"
---@param cmd table Command to run (list of strings)
---@param opts? TerminalOpenOptions
---@return number bufnr, number winid
function M.open_terminal(mode, cmd, opts)
  opts = opts or {}

  if mode == 'tab' then
    vim.cmd('tabnew')
  elseif mode == 'vsplit' then
    vim.cmd('vsplit')
  elseif mode == 'split' then
    vim.cmd('split')
  elseif mode == 'float' then
    return M.open_terminal_float(cmd, {
      window_options = opts.window_options,
      title = opts.title,
      on_exit = opts.on_exit,
    })
  end

  -- Create a new empty buffer for the terminal (vsplit/split shows the current
  -- buffer by default, which causes jobstart issues with non-empty buffers)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  local ok = vim.fn.jobstart(cmd, { term = true })
  if ok == -1 then
    vim.notify('[GitHub Actions] Failed to start terminal', vim.log.levels.ERROR)
  end

  if opts.on_exit then
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = bufnr,
      once = true,
      callback = function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.schedule(opts.on_exit)
        end
      end,
    })
  end

  return bufnr, winid
end

---Open a terminal in a floating window with auto-close behavior
---Creates a new buffer, opens it in a float, starts the given terminal command,
---binds 'q' to close the window, and auto-closes when the terminal process exits.
---@param cmd table Command to run (list of strings)
---@param opts? TerminalOpenOptions
---@return number bufnr, number winid
function M.open_terminal_float(cmd, opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)
  local title = opts.title
  local float_opts = vim.tbl_extend('keep', opts.window_options or {}, { title = title })
  local winid = M.open_float_window(bufnr, float_opts)

  local ok = vim.fn.jobstart(cmd, { term = true })
  if ok == -1 then
    vim.notify('[GitHub Actions] Failed to start terminal', vim.log.levels.ERROR)
  end

  vim.keymap.set('n', 'q', function()
    close_terminal_buffer_job(winid, bufnr)
  end, { buffer = bufnr, noremap = true, silent = true })

  vim.api.nvim_create_autocmd('TermClose', {
    buffer = bufnr,
    once = true,
    callback = function()
      close_terminal_buffer_job(winid, bufnr)

      if opts.on_exit then
        vim.schedule(opts.on_exit)
      end
    end,
  })
  return bufnr, winid
end

return M
