---@class LogViewer
local M = {}

---Check if logs can be viewed for a job
---@param run table Run object with status and databaseId
---@param job table Job object with status and name
---@return boolean can_view Whether logs can be viewed
---@return string|nil message Error message if logs cannot be viewed
function M.can_view_logs(run, job)
  -- Check if workflow run itself is still in progress
  -- Even if individual jobs are completed, logs are only available when the entire run completes
  if run.status == 'in_progress' or run.status == 'queued' then
    local message = string.format(
      'Workflow run #%d is still %s. Logs will be available when the entire workflow completes.',
      run.databaseId,
      run.status == 'in_progress' and 'running' or 'queued'
    )
    return false, message
  end

  -- Check if job is still in progress or queued
  if job.status == 'in_progress' or job.status == 'queued' then
    local message = string.format(
      'Job "%s" is still %s. Logs will be available when it completes.',
      job.name,
      job.status == 'in_progress' and 'running' or 'queued'
    )
    return false, message
  end

  return true, nil
end

---View logs for a job
---@param run table Run object with status, databaseId, and jobs
---@param job table Job object with status, name, and databaseId
function M.view_logs(run, job)
  if not run or not job then
    return
  end

  -- Check if logs can be viewed
  local can_view, message = M.can_view_logs(run, job)
  if not can_view then
    vim.schedule(function()
      vim.notify('[GitHub Actions] ' .. message, vim.log.levels.WARN)
    end)
    return
  end

  -- Create or reuse log buffer
  local logs_buffer = require('github-actions.history.ui.logs_buffer')
  local log_parser = require('github-actions.history.log_parser')
  local history = require('github-actions.history.api')
  local github_actions = require('github-actions')
  local config = github_actions.get_config()

  local title = string.format('Job: %s', job.name)
  local log_bufnr, _ = logs_buffer.create_buffer(title, run.databaseId, config.history)

  -- Check cache first
  local cached_formatted, _ = logs_buffer.get_cached_logs(run.databaseId, job.databaseId)
  if cached_formatted then
    -- Use cached logs
    logs_buffer.render(log_bufnr, cached_formatted)
    return
  end

  -- Show loading indicator only for new fetches
  logs_buffer.render(log_bufnr, 'Loading logs...')

  -- Fetch logs for the entire job
  history.fetch_logs(run.databaseId, job.databaseId, function(logs, err)
    vim.schedule(function()
      if err then
        logs_buffer.render(log_bufnr, 'Failed to fetch logs: ' .. err)
        vim.notify('[GitHub Actions] Failed to fetch logs: ' .. err, vim.log.levels.ERROR)
        return
      end

      -- Parse and format logs, removing ANSI escape sequences
      local formatted_logs = log_parser.parse(logs or '')

      -- Cache both raw and formatted logs
      logs_buffer.cache_logs(run.databaseId, job.databaseId, formatted_logs or 'No logs available', logs or '')

      -- Render the logs
      logs_buffer.render(log_bufnr, formatted_logs or 'No logs available')
    end)
  end)
end

return M
