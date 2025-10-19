local M = {}

---Fetch workflow runs using gh CLI
---@param workflow_file string Workflow file name (e.g., "ci.yml")
---@param callback fun(runs: table[]|nil, err: string|nil) Callback with runs or error
function M.fetch_runs(workflow_file, callback)
  local cmd = {
    'gh',
    'run',
    'list',
    '--workflow',
    workflow_file,
    '--json',
    'conclusion,createdAt,databaseId,displayTitle,headBranch,status,updatedAt',
  }

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, result.stderr)
        return
      end

      local ok, runs = pcall(vim.json.decode, result.stdout)
      if not ok then
        callback(nil, 'Failed to parse JSON response')
        return
      end

      callback(runs, nil)
    end)
  end)
end

return M
