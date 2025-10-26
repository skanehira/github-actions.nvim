---@class VersionInfo
---@field line number The 0-indexed line number in the buffer
---@field col number The 0-indexed column number in the buffer
---@field current_version? string The current version used (e.g., "v3", "main")
---@field current_hash? string The current commit hash if used
---@field latest_version? string The latest available version
---@field latest_hash? string The latest commit hash
---@field is_latest boolean Whether the current version is the latest
---@field error? string Error message if version check failed

---@class VirtualTextIcons
---@field outdated? string Icon for outdated versions (default: " ")
---@field latest? string Icon for latest versions (default: " ")
---@field error? string Icon for errors (default: " ")

---@class VirtualTextOptions
---@field icons? VirtualTextIcons Icons for version status
---@field highlight_latest? string Highlight for latest (default: "GitHubActionsVersionLatest")
---@field highlight_outdated? string Highlight for outdated (default: "GitHubActionsVersionOutdated")
---@field highlight_error? string Highlight for errors (default: "GitHubActionsVersionError")
---@field highlight_icon_latest? string Highlight for latest icon (default: "GitHubActionsIconLatest")
---@field highlight_icon_outdated? string Highlight for outdated icon (default: "GitHubActionsIconOutdated")
---@field highlight_icon_error? string Highlight for error icon (default: "GitHubActionsIconError")

---@class Display
local M = {}

-- Namespace for version virtual text
local namespace_id = nil

-- Default options based on docs/design.md
---@type VirtualTextOptions
M.default_options = {
  icons = {
    outdated = '',
    latest = '',
    error = '',
  },
  highlight_latest = 'GitHubActionsVersionLatest',
  highlight_outdated = 'GitHubActionsVersionOutdated',
  highlight_error = 'GitHubActionsVersionError',
  highlight_icon_latest = 'GitHubActionsIconLatest',
  highlight_icon_outdated = 'GitHubActionsIconOutdated',
  highlight_icon_error = 'GitHubActionsIconError',
}

---Get or create the namespace for virtual text
---@return number namespace_id
function M.get_namespace()
  if namespace_id == nil then
    namespace_id = vim.api.nvim_create_namespace('github_actions_virtual_text')
  end
  return namespace_id
end

---Merge user options with defaults
---@param opts? VirtualTextOptions User options
---@return table merged_opts
local function merge_opts(opts)
  if not opts then
    return vim.deepcopy(M.default_options)
  end

  local merged = vim.deepcopy(M.default_options)

  if opts.icons then
    if opts.icons.outdated ~= nil then
      merged.icons.outdated = opts.icons.outdated
    end
    if opts.icons.latest ~= nil then
      merged.icons.latest = opts.icons.latest
    end
    if opts.icons.error ~= nil then
      merged.icons.error = opts.icons.error
    end
  end
  if opts.highlight_latest then
    merged.highlight_latest = opts.highlight_latest
  end
  if opts.highlight_outdated then
    merged.highlight_outdated = opts.highlight_outdated
  end
  if opts.highlight_error then
    merged.highlight_error = opts.highlight_error
  end
  if opts.highlight_icon_latest then
    merged.highlight_icon_latest = opts.highlight_icon_latest
  end
  if opts.highlight_icon_outdated then
    merged.highlight_icon_outdated = opts.highlight_icon_outdated
  end
  if opts.highlight_icon_error then
    merged.highlight_icon_error = opts.highlight_icon_error
  end

  return merged
end

---Build virtual text chunks
---@param version_info VersionInfo Version information
---@param opts table Merged options
---@return table virt_text Array of [text, highlight] tuples
local function build_virt_text(version_info, opts)
  local virt_text = {}

  -- Handle error case
  if version_info.error then
    table.insert(virt_text, { opts.icons.error, opts.highlight_icon_error })
    table.insert(virt_text, { ' ' .. version_info.error, opts.highlight_error })
    return virt_text
  end

  -- Determine icon and highlights based on is_latest
  local icon = version_info.is_latest and opts.icons.latest or opts.icons.outdated
  local icon_hl = version_info.is_latest and opts.highlight_icon_latest or opts.highlight_icon_outdated
  local version_hl = version_info.is_latest and opts.highlight_latest or opts.highlight_outdated

  -- Add icon
  table.insert(virt_text, { icon, icon_hl })

  -- Add version
  if version_info.latest_version then
    table.insert(virt_text, { ' ' .. version_info.latest_version, version_hl })
  end

  return virt_text
end

---Set version text for a single action in a buffer
---@param bufnr number Buffer number
---@param version_info VersionInfo Version information for the action
---@param opts? VirtualTextOptions Display options
function M.set_version_text(bufnr, version_info, opts)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local merged_opts = merge_opts(opts)
  local ns = M.get_namespace()

  -- Build virtual text
  local virt_text = build_virt_text(version_info, merged_opts)

  -- Set extmark
  vim.api.nvim_buf_set_extmark(bufnr, ns, version_info.line, 0, {
    virt_text = virt_text,
    virt_text_pos = 'eol',
    priority = vim.highlight.priorities.user,
    right_gravity = true,
  })
end

---Set version text for multiple actions in a buffer
---@param bufnr number Buffer number
---@param version_infos VersionInfo[] List of version information
---@param opts? VirtualTextOptions Display options
function M.set_version_texts(bufnr, version_infos, opts)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Set version text for each version info
  for _, version_info in ipairs(version_infos) do
    M.set_version_text(bufnr, version_info, opts)
  end
end

---Clear all version text from a buffer
---@param bufnr number Buffer number
function M.clear_version_text(bufnr)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ns = M.get_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

---Clear and display version information (high-level UI function)
---@param bufnr number Buffer number
---@param version_infos VersionInfo[]|nil List of version information
---@param opts? VirtualTextOptions Display options
function M.show_versions(bufnr, version_infos, opts)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear existing version text
  M.clear_version_text(bufnr)

  -- Display new version infos
  if version_infos and #version_infos > 0 then
    M.set_version_texts(bufnr, version_infos, opts)
  end
end

return M
