local formatter = require('github-actions.history.ui.formatter')
local history = require('github-actions.history.api')
local buffer_utils = require('github-actions.shared.buffer_utils')
local highlighter = require('github-actions.history.ui.highlighter')
local cursor_tracker = require('github-actions.history.ui.cursor_tracker')
local loading_indicator = require('github-actions.history.ui.loading_indicator')
local log_viewer = require('github-actions.history.ui.log_viewer')
local config = require('github-actions.config')
local dispatch = require('github-actions.dispatch')
local select = require('github-actions.shared.select')
local url_module = require('github-actions.shared.url')

local M = {}

-- Store buffer-specific data
-- bufnr -> { runs = {...}, custom_icons = {...}, custom_highlights = {...} }
local buffer_data = {}

---Open a new window according to the specified mode
---@param mode string One of: "tab", "vsplit", "split", "current"
function M.open_window(mode)
  if mode == 'tab' then
    vim.cmd('tabnew')
  elseif mode == 'vsplit' then
    vim.cmd('vsplit')
  elseif mode == 'split' then
    vim.cmd('split')
  elseif mode == 'current' then
    -- Stay in current window
  else
    -- Default to tab if unknown mode
    vim.cmd('tabnew')
  end
end

---Create a new buffer for displaying workflow run history
---@param workflow_file string Workflow file name (e.g., "ci.yml") or branch name for branch mode
---@param workflow_filepath? string Full path to workflow file (e.g., ".github/workflows/ci.yml"), nil for branch mode
---@param opts? table Options table with optional fields: open_mode ("tab"|"vsplit"|"split"|"current"), buflisted (boolean), custom_keymaps (HistoryListKeymaps), branch (string)
---@return number bufnr Buffer number
---@return number winnr Window number
function M.create_buffer(workflow_file, workflow_filepath, opts)
  opts = opts or {}

  -- Get config defaults
  local defaults = config.get_defaults()
  local history_buffer_config = defaults.history.buffer.history

  -- Extract options with defaults
  local open_mode = opts.open_mode or history_buffer_config.open_mode
  local buflisted = opts.buflisted ~= nil and opts.buflisted or history_buffer_config.buflisted
  local window_options = opts.window_options or history_buffer_config.window_options
  local custom_keymaps = opts.custom_keymaps
  local branch = opts.branch

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
      -- Apply window options to existing window
      if window_options then
        vim.api.nvim_win_call(winid, function()
          for option, value in pairs(window_options) do
            vim.wo[option] = value
          end
        end)
      end
      return existing_bufnr, winid
    else
      -- Buffer exists but not displayed, open it according to open_mode
      M.open_window(open_mode)
      local new_winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(new_winid, existing_bufnr)
      -- Apply window options to new window
      if window_options then
        for option, value in pairs(window_options) do
          vim.wo[new_winid][option] = value
        end
      end
      return existing_bufnr, new_winid
    end
  end

  -- Create a new buffer (listed by default to avoid [No Name] buffers)
  local bufnr = vim.api.nvim_create_buf(buflisted, true)

  -- Set buffer options
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].bufhidden = 'hide' -- Changed from 'wipe' to 'hide' to preserve buffer
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false

  -- Set buffer name
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Open buffer according to open_mode
  M.open_window(open_mode)
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Apply window options to window
  if window_options then
    for option, value in pairs(window_options) do
      vim.wo[winnr][option] = value
    end
  end

  -- Get keymaps from config (use custom if provided, otherwise defaults)
  local keymaps = vim.tbl_deep_extend('force', defaults.history.keymaps.list, custom_keymaps or {})

  -- Initialize buffer data with workflow_file, workflow_filepath, keymaps, and branch
  buffer_data[bufnr] = {
    workflow_file = workflow_file,
    workflow_filepath = workflow_filepath,
    keymaps = keymaps,
    branch = branch,
  }

  -- Set up keymaps
  M.setup_keymaps(bufnr, keymaps)

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
  if not data then
    vim.notify('[GitHub Actions] Could not determine buffer data', vim.log.levels.ERROR)
    return
  end

  local custom_icons = data.custom_icons
  local custom_highlights = data.custom_highlights

  -- Show loading indicator
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Refreshing workflow runs...' })
  vim.bo[bufnr].modifiable = false

  -- Choose fetch method based on mode (branch mode vs workflow mode)
  local fetch_func
  local fetch_arg
  if data.branch then
    -- Branch filter mode
    fetch_func = history.fetch_runs_by_branch
    fetch_arg = data.branch
  elseif data.workflow_file then
    -- Workflow file mode
    fetch_func = history.fetch_runs
    fetch_arg = data.workflow_file
  else
    vim.notify('[GitHub Actions] Could not determine workflow file or branch', vim.log.levels.ERROR)
    return
  end

  -- Fetch fresh data from GitHub API
  fetch_func(fetch_arg, function(runs, err)
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

---Dispatch a workflow (with inputs and branch selection)
---@param bufnr number Buffer number
local function dispatch_workflow(bufnr)
  local data = buffer_data[bufnr]
  if not data or not data.workflow_filepath then
    vim.notify('[GitHub Actions] Could not determine workflow file path', vim.log.levels.ERROR)
    return
  end

  -- Use dispatch module to handle workflow_dispatch inputs and branch selection
  dispatch.dispatch_workflow_for_file(data.workflow_filepath)
end

---Execute rerun with given options
---@param bufnr number Buffer number
---@param run table Run object
---@param options? RerunOptions Rerun options
local function execute_rerun(bufnr, run, options)
  local rerun_type = (options and options.failed_only) and 'failed jobs' or 'all jobs'

  vim.notify(
    string.format('[GitHub Actions] Rerunning %s for run #%d...', rerun_type, run.databaseId),
    vim.log.levels.INFO
  )

  history.rerun(run.databaseId, function(err)
    vim.schedule(function()
      if err then
        vim.notify('[GitHub Actions] Failed to rerun: ' .. err, vim.log.levels.ERROR)
        return
      end

      vim.notify(
        string.format('[GitHub Actions] Workflow run #%d (%s) has been queued for rerun', run.databaseId, rerun_type),
        vim.log.levels.INFO
      )

      if vim.api.nvim_buf_is_valid(bufnr) then
        refresh_history(bufnr)
      end
    end)
  end, options)
end

---Rerun a workflow run at cursor
---@param bufnr number Buffer number
local function rerun_run(bufnr)
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

  -- If run failed, show picker to choose rerun type
  if run.conclusion == 'failure' then
    select.select({
      prompt = 'Select rerun option:',
      items = {
        { value = 'all', display = 'Rerun all jobs' },
        { value = 'failed', display = 'Rerun failed jobs only' },
      },
      on_select = function(option)
        local options = option == 'failed' and { failed_only = true } or nil
        execute_rerun(bufnr, run, options)
      end,
    })
  else
    -- For non-failed runs, rerun all directly
    execute_rerun(bufnr, run, nil)
  end
end

---Cancel a running workflow run at cursor
---@param bufnr number Buffer number
local function cancel_run(bufnr)
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

  -- Check if run is cancellable (only in_progress or queued runs can be cancelled)
  if run.status ~= 'in_progress' and run.status ~= 'queued' then
    local message = string.format(
      '[GitHub Actions] Run #%d is %s. Only in-progress or queued runs can be cancelled.',
      run.databaseId,
      run.status
    )
    vim.notify(message, vim.log.levels.WARN)
    return
  end

  vim.notify(string.format('[GitHub Actions] Cancelling workflow run #%d...', run.databaseId), vim.log.levels.INFO)

  history.cancel(run.databaseId, function(err)
    vim.schedule(function()
      if err then
        vim.notify('[GitHub Actions] Failed to cancel: ' .. err, vim.log.levels.ERROR)
        return
      end

      vim.notify(
        string.format('[GitHub Actions] Workflow run #%d has been cancelled', run.databaseId),
        vim.log.levels.INFO
      )

      -- Refresh the history buffer to show updated status
      if vim.api.nvim_buf_is_valid(bufnr) then
        refresh_history(bufnr)
      end
    end)
  end)
end

---Open workflow run or job URL in browser
---@param bufnr number Buffer number
local function open_in_browser(bufnr)
  local data = buffer_data[bufnr]
  if not data or not data.runs then
    return
  end

  -- Check if cursor is on a job
  local job_run_idx, job_idx = cursor_tracker.get_job_at_cursor(data.runs)
  if job_run_idx and job_idx then
    local run = data.runs[job_run_idx]
    local job = run.jobs[job_idx]

    url_module.get_repo_info(function(owner, repo, err)
      vim.schedule(function()
        if err then
          vim.notify('[GitHub Actions] ' .. err, vim.log.levels.ERROR)
          return
        end
        local url = url_module.build_job_url(owner, repo, run.databaseId, job.databaseId)
        url_module.open_url(url)
      end)
    end)
    return
  end

  -- Check if cursor is on a run
  local run_idx = cursor_tracker.get_run_at_cursor(bufnr, data.runs)
  if not run_idx then
    vim.notify('[GitHub Actions] Cursor is not on a run or job', vim.log.levels.WARN)
    return
  end

  local run = data.runs[run_idx]

  url_module.get_repo_info(function(owner, repo, err)
    vim.schedule(function()
      if err then
        vim.notify('[GitHub Actions] ' .. err, vim.log.levels.ERROR)
        return
      end
      local url = url_module.build_run_url(owner, repo, run.databaseId)
      url_module.open_url(url)
    end)
  end)
end

---Set up keymaps for the buffer
---@param bufnr number Buffer number
---@param keymaps HistoryListKeymaps Keymap configuration
function M.setup_keymaps(bufnr, keymaps)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Close buffer
  vim.keymap.set('n', keymaps.close, function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end, opts)

  -- Toggle expand/collapse
  vim.keymap.set('n', keymaps.expand, function()
    toggle_expand(bufnr)
  end, opts)

  -- Collapse
  vim.keymap.set('n', keymaps.collapse, function()
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

  -- Refresh
  vim.keymap.set('n', keymaps.refresh, function()
    refresh_history(bufnr)
  end, opts)

  -- Rerun
  vim.keymap.set('n', keymaps.rerun, function()
    rerun_run(bufnr)
  end, opts)

  -- Dispatch workflow
  vim.keymap.set('n', keymaps.dispatch, function()
    dispatch_workflow(bufnr)
  end, opts)

  -- Watch running workflow
  vim.keymap.set('n', keymaps.watch, function()
    watch_run(bufnr)
  end, opts)

  -- Cancel running workflow
  vim.keymap.set('n', keymaps.cancel, function()
    cancel_run(bufnr)
  end, opts)

  -- Open run or job in browser
  vim.keymap.set('n', keymaps.open_browser, function()
    open_in_browser(bufnr)
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
  local defaults = config.get_defaults()
  local highlights = config.merge_highlights(defaults.history.highlights, custom_highlights)

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

---Generate help text based on configured keymaps
---@param keymaps HistoryListKeymaps Keymap configuration
---@return string help_text Help text for the buffer
local function generate_help_text(keymaps)
  -- stylua: ignore start
  return string.format(
    '%s expand/view logs, %s collapse, %s refresh, %s rerun, %s dispatch, %s watch, %s cancel, %s open, %s close',
    keymaps.expand, keymaps.collapse, keymaps.refresh, keymaps.rerun, keymaps.dispatch, keymaps.watch,
    keymaps.cancel, keymaps.open_browser, keymaps.close
  )
  -- stylua: ignore end
end

---Render run list in the buffer
---@param bufnr number Buffer number
---@param runs table[] List of run objects
---@param custom_icons? HistoryIcons Custom icon configuration
---@param custom_highlights? HistoryHighlights Custom highlight configuration
function M.render(bufnr, runs, custom_icons, custom_highlights)
  -- Store buffer data for keymap handlers, preserving workflow_file, workflow_filepath, keymaps, and branch
  local existing_data = buffer_data[bufnr] or {}
  buffer_data[bufnr] = {
    workflow_file = existing_data.workflow_file,
    workflow_filepath = existing_data.workflow_filepath,
    keymaps = existing_data.keymaps,
    branch = existing_data.branch,
    runs = runs,
    custom_icons = custom_icons,
    custom_highlights = custom_highlights,
  }

  -- Merge icons with defaults
  local defaults = config.get_defaults()
  local icons = config.merge_icons(defaults.history.icons, custom_icons)

  -- Make buffer modifiable temporarily
  vim.bo[bufnr].modifiable = true

  local lines = {}

  -- Add keymap help text at the top (using configured keymaps)
  local keymaps = existing_data.keymaps or defaults.history.keymaps.list
  table.insert(lines, generate_help_text(keymaps))
  table.insert(lines, '')

  if #runs == 0 then
    table.insert(lines, 'No workflow runs found.')
  else
    -- Add each run
    for _, run in ipairs(runs) do
      table.insert(lines, formatter.format_run(run, nil, icons))

      -- If run is expanded and has jobs, render them
      if run.expanded and run.jobs then
        for _, job in ipairs(run.jobs) do
          table.insert(lines, formatter.format_job(job, icons))

          -- Render steps for this job
          if job.steps then
            for step_idx, step in ipairs(job.steps) do
              local is_last = step_idx == #job.steps
              table.insert(lines, formatter.format_step(step, is_last, icons))
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
