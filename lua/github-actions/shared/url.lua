local M = {}

---Get repository owner and name from current git directory
---@param callback fun(owner: string|nil, repo: string|nil, err: string|nil)
function M.get_repo_info(callback)
  vim.system({ 'gh', 'repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner' }, {
    text = true,
  }, function(result)
    if result.code ~= 0 then
      callback(nil, nil, result.stderr or 'Failed to get repo info')
      return
    end
    local name = vim.trim(result.stdout)
    local owner, repo = name:match('([^/]+)/(.+)')
    if not owner or not repo then
      callback(nil, nil, 'Failed to parse repo info: ' .. name)
      return
    end
    callback(owner, repo, nil)
  end)
end

---Build GitHub Actions workflow URL
---@param owner string Repository owner
---@param repo string Repository name
---@param workflow_file string Workflow file name (e.g., "ci.yml")
---@return string url Workflow URL
function M.build_workflow_url(owner, repo, workflow_file)
  return string.format('https://github.com/%s/%s/actions/workflows/%s', owner, repo, workflow_file)
end

---Build GitHub Actions run URL
---@param owner string Repository owner
---@param repo string Repository name
---@param run_id number Run ID
---@return string url Run URL
function M.build_run_url(owner, repo, run_id)
  return string.format('https://github.com/%s/%s/actions/runs/%d', owner, repo, run_id)
end

---Build GitHub Actions job URL
---@param owner string Repository owner
---@param repo string Repository name
---@param run_id number Run ID
---@param job_id number Job ID
---@return string url Job URL
function M.build_job_url(owner, repo, run_id, job_id)
  return string.format('https://github.com/%s/%s/actions/runs/%d/job/%d', owner, repo, run_id, job_id)
end

---Open URL in browser
---@param url string URL to open
function M.open_url(url)
  vim.ui.open(url)
end

return M
