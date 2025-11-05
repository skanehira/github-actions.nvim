---@class LoadingIndicator
local M = {}

---Show loading indicator on current line using virtual text
---@param bufnr number Buffer number
---@return number line_idx Line index where loading indicator was added
function M.show(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_idx = cursor[1] - 1

  -- Create a namespace for loading indicators
  local ns = vim.api.nvim_create_namespace('github-actions-loading')

  -- Clear any existing loading indicators
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Add virtual text to show loading state (doesn't modify buffer content)
  vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
    virt_text = { { '  (Loading jobs...)', 'GitHubActionsHistoryTime' } },
    virt_text_pos = 'eol',
  })

  return line_idx
end

---Clear loading indicator
---@param bufnr number Buffer number
function M.clear(bufnr)
  local ns = vim.api.nvim_create_namespace('github-actions-loading')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

return M
