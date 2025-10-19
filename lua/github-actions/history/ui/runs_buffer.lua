local formatter = require('github-actions.history.ui.formatter')
local history = require('github-actions.workflow.history')

local M = {}

-- Store buffer-specific data
-- bufnr -> { runs = {...}, custom_icons = {...}, custom_highlights = {...} }
local buffer_data = {}

---Create a new buffer for displaying workflow run history
---@param workflow_file string Workflow file name (e.g., "ci.yml")
---@return number bufnr Buffer number
---@return number winnr Window number
function M.create_buffer(workflow_file)
  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false

  -- Set buffer name
  local bufname = string.format('[GitHub Actions] %s - Run History', workflow_file)
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Open buffer in a new tab
  vim.cmd('tabnew')
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

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

---Get run index from cursor line
---@param bufnr number Buffer number
---@return number|nil run_idx Run index (1-based) or nil if not on a run line
local function get_run_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_idx = cursor[1] - 1 -- Convert to 0-based

  local data = buffer_data[bufnr]
  if not data or not data.runs then
    return nil
  end

  -- Find which run this line belongs to
  local current_line = 0 -- First run starts at line 0 (0-based)
  for run_idx, run in ipairs(data.runs) do
    if line_idx == current_line then
      return run_idx
    end

    current_line = current_line + 1

    -- Count expanded lines for this run
    if run.expanded and run.jobs then
      for _, job in ipairs(run.jobs) do
        current_line = current_line + 1
        if job.steps then
          current_line = current_line + #job.steps
        end
      end
    end
  end

  return nil
end

---Get job at cursor position
---@param bufnr number Buffer number
---@return number|nil run_idx Index of the run
---@return number|nil job_idx Index of the job
local function get_job_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_idx = cursor[1] - 1

  local data = buffer_data[bufnr]
  if not data or not data.runs then
    return nil, nil
  end

  local current_line = 0 -- First run starts at line 0

  for run_idx, run in ipairs(data.runs) do
    if line_idx == current_line then
      -- Cursor is on run line
      return nil, nil
    end

    current_line = current_line + 1

    -- Check expanded lines for this run
    if run.expanded and run.jobs then
      for job_idx, job in ipairs(run.jobs) do
        if line_idx == current_line then
          -- Cursor is on job line
          return run_idx, job_idx
        end

        current_line = current_line + 1

        if job.steps then
          for _, _ in ipairs(job.steps) do
            current_line = current_line + 1
          end
        end
      end
    end
  end

  return nil, nil
end

---Show loading indicator on current line using virtual text
---@param bufnr number Buffer number
---@return number line_idx Line index where loading indicator was added
local function show_loading_indicator(bufnr)
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
local function clear_loading_indicator(bufnr)
  local ns = vim.api.nvim_create_namespace('github-actions-loading')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

---View logs for a job
---@param bufnr number Buffer number
---@param run_idx number Index of the run in the runs array
---@param job_idx number Index of the job in the jobs array
local function view_job_logs(bufnr, run_idx, job_idx)
  local data = buffer_data[bufnr]
  if not data or not data.runs then
    return
  end

  local run = data.runs[run_idx]
  if not run or not run.jobs then
    return
  end

  local job = run.jobs[job_idx]
  if not job then
    return
  end

  -- Create or reuse log buffer
  local logs_buffer = require('github-actions.history.ui.logs_buffer')
  local log_parser = require('github-actions.history.log_parser')
  local github_actions = require('github-actions')
  local config = github_actions.get_config()

  local title = string.format('Job: %s', job.name)
  local log_bufnr, _ = logs_buffer.create_buffer(title, run.databaseId, config.history)

  -- Check cache first
  local cached_logs = logs_buffer.get_cached_logs(run.databaseId, job.databaseId)
  if cached_logs then
    -- Use cached logs
    logs_buffer.render(log_bufnr, cached_logs)
    return
  end

  -- Show loading indicator only for new fetches
  logs_buffer.render(log_bufnr, 'Loading logs...')

  -- Fetch logs for the entire job
  history.fetch_logs(run.databaseId, job.databaseId, function(logs, err)
    vim.schedule(function()
      if err then
        logs_buffer.render(log_bufnr, 'Failed to fetch logs: ' .. err)
        vim.notify('Failed to fetch logs: ' .. err, vim.log.levels.ERROR)
        return
      end

      -- Parse and format logs, removing ANSI escape sequences
      local formatted_logs = log_parser.parse(logs or '')

      -- Cache the formatted logs
      logs_buffer.cache_logs(run.databaseId, job.databaseId, formatted_logs or 'No logs available')

      -- Render the logs
      logs_buffer.render(log_bufnr, formatted_logs or 'No logs available')
    end)
  end)
end

---Toggle expand/collapse for run at cursor, or view logs for job
---@param bufnr number Buffer number
local function toggle_expand(bufnr)
  -- First, check if cursor is on a job
  local job_run_idx, job_idx = get_job_at_cursor(bufnr)
  if job_run_idx and job_idx then
    -- Cursor is on a job, view logs for entire job
    view_job_logs(bufnr, job_run_idx, job_idx)
    return
  end

  -- Not on a job, check if on a run
  local run_idx = get_run_at_cursor(bufnr)
  if not run_idx then
    return
  end

  local data = buffer_data[bufnr]
  if not data or not data.runs then
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
    show_loading_indicator(bufnr)

    -- Need to fetch jobs first
    history.fetch_jobs(run.databaseId, function(jobs_response, err)
      if err then
        -- Clear loading indicator and show error
        vim.schedule(function()
          clear_loading_indicator(bufnr)
          M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
          vim.notify('Failed to fetch jobs: ' .. err, vim.log.levels.ERROR)
        end)
        return
      end

      if jobs_response and jobs_response.jobs then
        vim.schedule(function()
          clear_loading_indicator(bufnr)
          run.jobs = jobs_response.jobs
          run.expanded = true
          M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
        end)
      end
    end)
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
    local run_idx = get_run_at_cursor(bufnr)
    if not run_idx then
      return
    end

    local data = buffer_data[bufnr]
    if not data or not data.runs then
      return
    end

    local run = data.runs[run_idx]
    if run.expanded then
      run.expanded = false
      M.render(bufnr, data.runs, data.custom_icons, data.custom_highlights)
    end
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
  local ns = vim.api.nvim_create_namespace('github-actions-history')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Merge custom highlights with defaults
  local highlights = formatter.merge_highlights(custom_highlights)

  -- Highlight each run line and expanded content
  local current_line = 0 -- First run starts at line 0 (0-based)
  for _, run in ipairs(runs) do
    local line = vim.api.nvim_buf_get_lines(bufnr, current_line, current_line + 1, false)[1]

    -- Highlight status icon
    local hl_group = highlights.queued
    if run.status == 'completed' then
      if run.conclusion == 'success' then
        hl_group = highlights.success
      elseif run.conclusion == 'failure' then
        hl_group = highlights.failure
      elseif run.conclusion == 'cancelled' or run.conclusion == 'skipped' then
        hl_group = highlights.cancelled
      end
    elseif run.status == 'in_progress' then
      hl_group = highlights.running
    end
    vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, 0, {
      end_col = 1,
      hl_group = hl_group,
    })

    -- Highlight run ID (#12345)
    local id_start = line:find('#')
    local id_end = nil
    if id_start then
      id_end = line:find('%s', id_start)
      if id_end then
        vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, id_start - 1, {
          end_col = id_end - 1,
          hl_group = highlights.run_id,
        })
      end
    end

    -- Highlight branch name (before first colon)
    if id_end then
      local branch_end = line:find(':', id_end)
      if branch_end then
        vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, id_end, {
          end_col = branch_end,
          hl_group = highlights.branch,
        })
      end
    end

    -- Highlight time info (last two columns)
    local time_pattern = '%d+[smhdwy]+ ago'
    local time_start = line:find(time_pattern)
    if time_start then
      vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, time_start - 1, {
        end_line = current_line,
        end_col = #line,
        hl_group = highlights.time,
      })
    end

    current_line = current_line + 1

    -- Highlight expanded jobs and steps
    if run.expanded and run.jobs then
      for _, job in ipairs(run.jobs) do
        local job_line = vim.api.nvim_buf_get_lines(bufnr, current_line, current_line + 1, false)[1]

        -- Highlight job status icon
        local job_hl_group = highlights.queued
        if job.status == 'completed' then
          if job.conclusion == 'success' then
            job_hl_group = highlights.success
          elseif job.conclusion == 'failure' then
            job_hl_group = highlights.failure
          elseif job.conclusion == 'skipped' then
            job_hl_group = highlights.cancelled
          end
        elseif job.status == 'in_progress' then
          job_hl_group = highlights.running
        end
        vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, 2, {
          end_col = 3,
          hl_group = job_hl_group,
        })

        -- Highlight "Job:" text
        local job_start = job_line:find('Job:')
        if job_start then
          vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, job_start - 1, {
            end_col = job_start + 3,
            hl_group = highlights.job_name,
          })

          -- Highlight job name
          local name_start = job_start + 5
          local time_start_job = job_line:find('%d+[smh]', name_start)
          local running_start = job_line:find('%(running%)', name_start)
          local name_end = time_start_job or running_start or #job_line
          if name_start < name_end then
            vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, name_start - 1, {
              end_col = name_end - 1,
              hl_group = highlights.job_name,
            })
          end

          -- Highlight duration/status
          if time_start_job or running_start then
            vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, name_end - 1, {
              end_col = #job_line,
              hl_group = highlights.time,
            })
          end
        end

        current_line = current_line + 1

        -- Highlight steps
        if job.steps then
          for _, step in ipairs(job.steps) do
            local step_line = vim.api.nvim_buf_get_lines(bufnr, current_line, current_line + 1, false)[1]

            -- Highlight tree prefix (├─ or └─)
            local prefix_end = step_line:find('─')
            if prefix_end then
              vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, 0, {
                end_col = prefix_end + 1,
                hl_group = highlights.tree_prefix,
              })
            end

            -- Highlight step status icon
            local step_hl_group = highlights.queued
            if step.status == 'completed' then
              if step.conclusion == 'success' then
                step_hl_group = highlights.success
              elseif step.conclusion == 'failure' then
                step_hl_group = highlights.failure
              elseif step.conclusion == 'skipped' then
                step_hl_group = highlights.cancelled
              end
            elseif step.status == 'in_progress' then
              step_hl_group = highlights.running
            end
            -- Icon is after the tree prefix
            local icon_pos = prefix_end and prefix_end + 2 or 4
            vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, icon_pos, {
              end_col = icon_pos + 1,
              hl_group = step_hl_group,
            })

            -- Highlight step name
            local name_start_pos = icon_pos + 2
            local time_start_step = step_line:find('%d+[smh]', name_start_pos)
            local skipped_start = step_line:find('%(skipped%)', name_start_pos)
            local running_start_step = step_line:find('%(running%)', name_start_pos)
            local name_end_pos = time_start_step or skipped_start or running_start_step or #step_line
            if name_start_pos < name_end_pos then
              vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, name_start_pos, {
                end_col = name_end_pos - 1,
                hl_group = highlights.step_name,
              })
            end

            -- Highlight duration/status
            if time_start_step or skipped_start or running_start_step then
              vim.api.nvim_buf_set_extmark(bufnr, ns, current_line, name_end_pos - 1, {
                end_col = #step_line,
                hl_group = highlights.time,
              })
            end

            current_line = current_line + 1
          end
        end
      end
    end
  end

  -- Highlight footer
  local footer_line = current_line + 1
  local footer_text = vim.api.nvim_buf_get_lines(bufnr, footer_line, footer_line + 1, false)[1]
  if footer_text then
    vim.api.nvim_buf_set_extmark(bufnr, ns, footer_line, 0, {
      end_line = footer_line,
      end_col = #footer_text,
      hl_group = highlights.time,
    })
  end
end

---Render run list in the buffer
---@param bufnr number Buffer number
---@param runs table[] List of run objects
---@param custom_icons? HistoryIcons Custom icon configuration
---@param custom_highlights? HistoryHighlights Custom highlight configuration
function M.render(bufnr, runs, custom_icons, custom_highlights)
  -- Store buffer data for keymap handlers
  buffer_data[bufnr] = {
    runs = runs,
    custom_icons = custom_icons,
    custom_highlights = custom_highlights,
  }

  -- Make buffer modifiable temporarily
  vim.bo[bufnr].modifiable = true

  local lines = {}

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

  table.insert(lines, '')
  table.insert(lines, 'Press <CR> to expand run / view job logs, <BS> to collapse, q to close')

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
