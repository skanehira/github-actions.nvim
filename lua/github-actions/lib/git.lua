---@class Git
local M = {}

---Parse git branches from git command output and return local branches
---@param stdout string Output from git branch command
---@return string[] branches List of branch names
function M.parse_branches(stdout)
  local branches = {}

  for branch in stdout:gmatch('[^\n]+') do
    -- Remove any whitespace
    branch = vim.trim(branch)
    -- Skip remote tracking branches (origin/*) and remote name itself (origin)
    if branch ~= '' and not branch:match('^origin/?') then
      table.insert(branches, branch)
    end
  end

  return branches
end

---Parse git branches from git command output and return remote branches only
---@param stdout string Output from git branch command
---@return string[] branches List of remote branch names (without origin/ prefix)
function M.parse_remote_branches(stdout)
  local branches = {}

  for branch in stdout:gmatch('[^\n]+') do
    -- Remove any whitespace
    branch = vim.trim(branch)
    -- Only include origin/* branches, skip HEAD references
    if branch ~= '' and branch:match('^origin/') and not branch:match('HEAD') then
      -- Remove origin/ prefix
      local normalized = branch:gsub('^origin/', '')
      table.insert(branches, normalized)
    end
  end

  return branches
end

---Normalize branch name by removing origin/ prefix
---@param branch string Branch name (e.g., "origin/main" or "main")
---@return string normalized Normalized branch name (e.g., "main")
function M.normalize_branch_name(branch)
  local normalized = branch:gsub('^origin/', '')
  return normalized
end

---Sort branches with default branch first
---@param branches string[] List of branches
---@param default_branch string Name of default branch
---@return string[] branches Sorted list with default branch first
function M.sort_branches_by_default(branches, default_branch)
  local idx = nil
  for i, branch in ipairs(branches) do
    if branch == default_branch then
      idx = i
      break
    end
  end
  if idx then
    table.remove(branches, idx)
    table.insert(branches, 1, default_branch)
  end
  return branches
end

---Execute git command
---@param cmd string[] Command to execute
---@return string stdout Command output
---@return number exit_code Exit code (0 for success)
---@return string stderr Error output
function M.execute_git_command(cmd)
  local stdout = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error
  -- vim.fn.system returns stderr in stdout when command fails
  local stderr = exit_code ~= 0 and stdout or ''
  return stdout, exit_code, stderr
end

---Get git repository root directory
---@return string|nil git_root The git root directory path, or nil if not in a git repository
function M.get_git_root()
  local stdout, exit_code = M.execute_git_command({ 'git', 'rev-parse', '--show-toplevel' })
  if exit_code ~= 0 then
    return nil
  end
  -- Remove trailing whitespace/newline
  return vim.trim(stdout)
end

---Get available git branches
---@return string[] branches List of branches with default branch first
function M.get_branches()
  -- Get all branches
  local stdout, exit_code = M.execute_git_command({ 'git', 'branch', '-a', '--format=%(refname:short)' })
  if exit_code ~= 0 then
    return {}
  end

  local branches = M.parse_branches(stdout)

  -- Get default branch
  local default_stdout, default_exit_code = M.execute_git_command({ 'git', 'symbolic-ref', 'refs/remotes/origin/HEAD' })
  local default_branch = 'main' -- Fallback
  if default_exit_code == 0 then
    default_branch = default_stdout:gsub('^refs/remotes/origin/', ''):gsub('%s+$', '')
  end

  -- Sort branches with default first
  branches = M.sort_branches_by_default(branches, default_branch)

  return branches
end

---Get available remote branches (origin/*)
---@return string[] branches List of remote branches (without origin/ prefix) with default branch first
function M.get_remote_branches()
  -- Get remote branches only
  local stdout, exit_code = M.execute_git_command({ 'git', 'branch', '-r', '--format=%(refname:short)' })
  if exit_code ~= 0 then
    return {}
  end

  local branches = M.parse_remote_branches(stdout)

  -- Get default branch
  local default_stdout, default_exit_code = M.execute_git_command({ 'git', 'symbolic-ref', 'refs/remotes/origin/HEAD' })
  local default_branch = 'main' -- Fallback without origin/ prefix
  if default_exit_code == 0 then
    default_branch = default_stdout:gsub('^refs/remotes/origin/', ''):gsub('%s+$', '')
  end

  -- Sort branches with default first
  branches = M.sort_branches_by_default(branches, default_branch)

  return branches
end

return M
