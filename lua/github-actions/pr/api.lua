local M = {}

---@class PR
---@field number number PR number
---@field title string PR title
---@field headRefName string Source branch name
---@field state string PR state (OPEN, CLOSED, MERGED)
---@field url string PR URL

---@class BranchWithPR
---@field branch string Branch name
---@field pr_number? number PR number (if PR exists)
---@field pr_title? string PR title (if PR exists)

---Get current branch name
---@return string|nil branch_name Current branch name or nil if not in git repo
function M.get_current_branch()
  local result = vim.fn.system('git branch --show-current')
  local branch = result:gsub('%s+$', '') -- Trim trailing whitespace/newline
  if branch == '' then
    return nil
  end
  return branch
end

---Fetch remote branches using git
---@param callback fun(branches: string[]|nil, err: string|nil)
function M.fetch_remote_branches(callback)
  local cmd = { 'git', 'branch', '-r', '--format=%(refname:short)' }

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, result.stderr)
        return
      end

      local branches = {}
      for line in result.stdout:gmatch('[^\n]+') do
        -- Remove origin/ prefix
        local branch = line:gsub('^origin/', '')
        if branch ~= '' and branch ~= 'HEAD' then
          table.insert(branches, branch)
        end
      end

      callback(branches, nil)
    end)
  end)
end

---Fetch open PRs using gh CLI
---@param callback fun(prs: PR[]|nil, err: string|nil)
function M.fetch_open_prs(callback)
  local cmd = {
    'gh',
    'pr',
    'list',
    '--state',
    'open',
    '--json',
    'number,title,headRefName,state,url',
  }

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, result.stderr)
        return
      end

      local ok, prs = pcall(vim.json.decode, result.stdout)
      if not ok then
        callback(nil, 'Failed to parse JSON response')
        return
      end

      callback(prs, nil)
    end)
  end)
end

---Fetch branches with PR info merged
---@param callback fun(branches: BranchWithPR[]|nil, err: string|nil)
function M.fetch_branches_with_prs(callback)
  -- First fetch remote branches
  M.fetch_remote_branches(function(branches, branch_err)
    if branch_err then
      callback(nil, branch_err)
      return
    end

    -- Then fetch open PRs
    M.fetch_open_prs(function(prs, pr_err)
      if pr_err then
        callback(nil, pr_err)
        return
      end

      -- Create a map of branch -> PR info
      local pr_map = {}
      for _, pr in ipairs(prs or {}) do
        pr_map[pr.headRefName] = pr
      end

      -- Merge branches with PR info
      local result = {}
      for _, branch in ipairs(branches or {}) do
        local pr = pr_map[branch]
        if pr then
          table.insert(result, {
            branch = branch,
            pr_number = pr.number,
            pr_title = pr.title,
          })
        else
          table.insert(result, {
            branch = branch,
          })
        end
      end

      callback(result, nil)
    end)
  end)
end

return M
