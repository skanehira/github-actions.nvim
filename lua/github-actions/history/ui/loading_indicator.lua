---@class LoadingIndicator
local M = {}

local DEFAULT_NAMESPACE = 'github-actions-loading'

---@class LoadingIndicatorOptions
---@field line? number 0-based line to mark (default: cursor line)
---@field text? string Virtual text to display (default: "  (Loading jobs...)")
---@field namespace? string Extmark namespace (default: "github-actions-loading")

---Show loading indicator using virtual text
---@param bufnr number Buffer number
---@param opts? LoadingIndicatorOptions
---@return number line_idx Line index where loading indicator was added
function M.show(bufnr, opts)
  opts = opts or {}
  local line_idx = opts.line or (vim.api.nvim_win_get_cursor(0)[1] - 1)

  local ns = vim.api.nvim_create_namespace(opts.namespace or DEFAULT_NAMESPACE)

  -- Clear any existing loading indicators
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Add virtual text to show loading state (doesn't modify buffer content)
  vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
    virt_text = { { opts.text or '  (Loading jobs...)', 'GitHubActionsHistoryTime' } },
    virt_text_pos = 'eol',
  })

  return line_idx
end

---Clear loading indicator
---@param bufnr number Buffer number
---@param namespace? string Extmark namespace (default: "github-actions-loading")
function M.clear(bufnr, namespace)
  local ns = vim.api.nvim_create_namespace(namespace or DEFAULT_NAMESPACE)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

return M
