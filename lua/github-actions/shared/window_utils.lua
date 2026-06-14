---@class WindowUtils
local M = {}

---Sets the window_options to the specified window
---@param winid integer
---@param window_options table<string, any>
function M.set_window_options(winid, window_options)
  for option, value in pairs(window_options) do
    vim.wo[winid][option] = value
  end
end

return M
