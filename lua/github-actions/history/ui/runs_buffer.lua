local formatter = require('github-actions.history.ui.formatter')
local history = require('github-actions.history.api')
local buffer_utils = require('github-actions.shared.buffer_utils')
local highlighter = require('github-actions.history.ui.highlighter')
local cursor_tracker = require('github-actions.history.ui.cursor_tracker')
local loading_indicator = require('github-actions.history.ui.loading_indicator')
local log_viewer = require('github-actions.history.ui.log_viewer')

local M = {}

-- Store buffer-specific data
-- bufnr -> { runs = {...}, custom_icons = {...}, custom_highlights = {...} }
local buffer_data = {}

---Create a new buffer for displaying workflow run history
---@param workflow_file string Workflow file name (e.g., "ci.yml")
---@param open_in_new_tab? boolean Whether to open in a new tab (default: true)
---@return number bufnr Buffer number
---@return number winnr Window number
function M.create_buffer(workflow_file, open_in_new_tab)
  if open_in_new_tab == nil then
    open_in_new_tab = true
  end

  local bufname = string.format('[GitHub Actions] %s - Run History', workflow_file)

  -- Check if buffer with this name already exists
  local existing_bufnr = vim.fn.bufnr(bufname)
  if existing_bufnr ~= -1 and vim.api.nvim_buf_is_valid(existing_bufnr) then
    -- Buffer exists, find its window across all tab pages
    local winid = buffer_utils.find_window_for_buffer(existing_bufnr)
    if winid then
      -- Buffer is already displayed in a window
      -- Return the buffer and window where it's displayed without switching to it
      -- The subsequent render() call will update the buffer content
      return existing_bufnr, winid
    else
      -- Buffer exists but not displayed, open it in new tab if requested
      if open_in_new_tab then
        vim.cmd('tabnew')
      end
      local new_winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(new_winid, existing_bufnr)
      return existing_bufnr, new_winid
    end
  end

  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false

  -- Set buffer name
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Open buffer in a new tab if requested
  if open_in_new_tab then
    vim.cmd('tabnew')
  end
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Initialize buffer data with workflow_file
  buffer_data[bufnr] = {
    workflow_file = workflow_file,
  }

  -- Set up keymaps
  M.setup_keymaps(bufnr)

  -- Clean up buffer data when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    callback = function()
      buffer_data[bufnr] = nil
    end,
  })

  return bufnr, winnr
end

---Toggle expand/collapse for run at cursor, or view logs for job
---@param bufnr number Buffer number
local function toggle_expand(bufnr)
  local data = buffer_data[bufnr]
  if not data or not data.runs then
    return
  end

  -- First, check if cursor is on a job
  local job_run_idx, job_idx = cursor_tracker.get_job_at_cursor(data.runs)
  if job_run_idx and job_idx then
    -- Cursor is on a job, view logs for entire job
    local run = data.runs[job_run_idx]
    local job = run and run.jobs and run.jobs[job_idx]
    if run and job then
      log_viewer.view_logs(run, job)
    end
    return
  end

  -- Not on a job, check if on a run
  local run_idx = cursor_tracker.get_run_at_cursor(bufnr, data.runs)
  if not run_idx then
    return
  end

  local run = data.runs[run_idx]

  -- If already expanded, collapse it
  if run.expanded then
    run.expanded = false
    M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
    return
  end

  -- If not expanded, fetch jobs and expand
  if run.jobs then
    -- Jobs already fetched, just expand
    run.expanded = true
    M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
  else
    -- Show loading indicator
    loading_indicator.show(bufnr)

    -- Need to fetch jobs first
    history.fetch_jobs(run.databaseId, function(jobs_response, err)
      if err then
        -- Clear loading indicator and show error
        vim.schedule(function()
          loading_indicator.clear(bufnr)
          M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
          vim.notify('[GitHub Actions] Failed to fetch jobs: ' .. err, vim.log.levels.ERROR)
        end)
        return
      end

      if jobs_response and jobs_response.jobs then
        vim.schedule(function()
          loading_indicator.clear(bufnr)
          run.jobs = jobs_response.jobs
          run.expanded = true
          M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
        end)
      end
    end)
  end
end

---Refresh workflow run history
---@param bufnr number Buffer number
local function refresh_history(bufnr)
  -- Get current buffer data
  local data = buffer_data[bufnr]
  if not data or not data.workflow_file then
    vim.notify('[GitHub Actions] Could not determine workflow file', vim.log.levels.ERROR)
    return
  end

  local workflow_file = data.workflow_file
  local custom_icons = data.custom_icons
  local custom_highlights = data.custom_highlights

  -- Show loading indicator
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Refreshing workflow runs...' })
  vim.bo[bufnr].modifiable = false

  -- Fetch fresh data from GitHub API
  history.fetch_runs(workflow_file, function(runs, err)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if err then
        vim.notify('[GitHub Actions] Failed to refresh: ' .. err, vim.log.levels.ERROR)
        return
      end

      if not runs then
        vim.notify('[GitHub Actions] No runs data returned', vim.log.levels.ERROR)
        return
      end

      -- Re-render with fresh data
      M.render(bufnr, runs, custom_icons, custom_highlights)
      vim.notify('[GitHub Actions] Workflow runs refreshed', vim.log.levels.INFO)
    end)
  end)
end

---Watch a running workflow run
---@param bufnr number Buffer number
local function watch_run(bufnr)
  local data = buffer_data[bufnr]
  if not data or not data.runs then
    return
  end

  local run_idx = cursor_tracker.get_run_at_cursor(bufnr, data.runs)
  if not run_idx then
    vim.notify('[GitHub Actions] Cursor is not on a run', vim.log.levels.WARN)
    return
  end

  local run = data.runs[run_idx]

  -- Check if run is watchable (in_progress or queued runs)
  if run.status ~= 'in_progress' and run.status ~= 'queued' then
    local message = string.format(
      '[GitHub Actions] Run #%d is %s. Only in-progress or queued runs can be watched.',
      run.databaseId,
      run.status
    )
    vim.notify(message, vim.log.levels.WARN)
    return
  end

  -- Store the current window to return focus later
  local history_winid = vim.api.nvim_get_current_win()

  -- Execute gh run watch in a terminal with auto-refresh on exit
  local cmd = string.format('gh run watch %d', run.databaseId)
  vim.cmd('new | terminal ' .. cmd)

  -- Set up autocmd to refresh history buffer when terminal exits
  local term_bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = term_bufnr,
    once = true,
    callback = function()
      vim.schedule(function()
        -- Only refresh if the original buffer still exists
        if vim.api.nvim_buf_is_valid(bufnr) then
          refresh_history(bufnr)
        end
      end)
    end,
  })

  -- Return focus to history buffer window and ensure normal mode
  if vim.api.nvim_win_is_valid(history_winid) then
    vim.api.nvim_set_current_win(history_winid)
    -- Stop insert mode if it was activated by terminal startinsert
    vim.cmd('stopinsert')
  end
end

---Set up keymaps for the buffer
---@param bufnr number Buffer number
function M.setup_keymaps(bufnr)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Close buffer with 'q'
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end, opts)

  -- Toggle expand/collapse with <CR>
  vim.keymap.set('n', '<CR>', function()
    toggle_expand(bufnr)
  end, opts)

  -- Collapse with <BS>
  vim.keymap.set('n', '<BS>', function()
    local data = buffer_data[bufnr]
    if not data or not data.runs then
      return
    end

    local run_idx = cursor_tracker.get_run_at_cursor(bufnr, data.runs)
    if not run_idx then
      return
    end

    local run = data.runs[run_idx]
    if run.expanded then
      run.expanded = false
      M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
    end
  end, opts)

  -- Refresh with 'R'
  vim.keymap.set('n', 'R', function()
    refresh_history(bufnr)
  end, opts)

  -- Watch running workflow with 'W'
  vim.keymap.set('n', 'W', function()
    watch_run(bufnr)
  end, opts)
end

---Setup syntax highlighting for the buffer
---@param bufnr number Buffer number
local function setup_buffer_highlights(bufnr)
  -- Set filetype for syntax
  vim.bo[bufnr].filetype = 'github-actions-history'
end

---Apply syntax highlighting to buffer lines
---@param bufnr number Buffer number
---@param runs table[] List of run objects
---@param custom_highlights? HistoryHighlights Custom highlight configuration
local function apply_highlights(bufnr, runs, custom_highlights)
  -- Merge custom highlights with defaults
  local highlights = formatter.merge_highlights(custom_highlights)

  -- Delegate to highlighter module
  highlighter.apply_highlights(bufnr, runs, highlights)
end

---Show loading message in buffer
---@param bufnr number Buffer number
function M.show_loading(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Loading workflow runs...' })
  vim.bo[bufnr].modifiable = false
end

---Render run list in the buffer
---@param bufnr number Buffer number
---@param runs table[] List of run objects
---@param custom_icons? HistoryIcons Custom icon configuration
---@param custom_highlights? HistoryHighlights Custom highlight configuration
function M.render(bufnr, runs, custom_icons, custom_highlights)
  -- Store buffer data for keymap handlers, preserving workflow_file
  local existing_data = buffer_data[bufnr] or {}
  buffer_data[bufnr] = {
    workflow_file = existing_data.workflow_file,
    runs = runs,
    custom_icons = custom_icons,
    custom_highlights = custom_highlights,
  }

  -- Make buffer modifiable temporarily
  vim.bo[bufnr].modifiable = true

  local lines = {}

  -- Add keymap help text at the top
  table.insert(
    lines,
    'Press <CR> to expand run / view job logs, <BS> to collapse, R to refresh, W to watch run, q to close'
  )
  table.insert(lines, '')

  if #runs == 0 then
    table.insert(lines, 'No workflow runs found.')
  else
    -- Add each run
    for _, run in ipairs(runs) do
      table.insert(lines, formatter.format_run(run, nil, custom_icons))

      -- If run is expanded and has jobs, render them
      if run.expanded and run.jobs then
        for _, job in ipairs(run.jobs) do
          table.insert(lines, formatter.format_job(job, custom_icons))

          -- Render steps for this job
          if job.steps then
            for step_idx, step in ipairs(job.steps) do
              local is_last = step_idx == #job.steps
              table.insert(lines, formatter.format_step(step, is_last, custom_icons))
            end
          end
        end
      end
    end
  end

  -- Set buffer lines
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights (highlight groups are already setup in init.lua)
  setup_buffer_highlights(bufnr)
  if #runs > 0 then
    apply_highlights(bufnr, runs, custom_highlights)
  end

  -- Make buffer read-only again
  vim.bo[bufnr].modifiable = false
end

return M
