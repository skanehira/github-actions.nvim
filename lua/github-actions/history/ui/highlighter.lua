---@class Highlighter
local M = {}

---Get highlight group for status and conclusion
---@param status string Status (completed, in_progress, queued, etc.)
---@param conclusion? string Conclusion (success, failure, cancelled, skipped, etc.)
---@param highlights table Highlight configuration
---@return string hl_group Highlight group name
function M.get_status_highlight(status, conclusion, highlights)
  if status == 'completed' then
    if conclusion == 'success' then
      return highlights.success
    elseif conclusion == 'failure' then
      return highlights.failure
    elseif conclusion == 'cancelled' or conclusion == 'skipped' then
      return highlights.cancelled
    end
  elseif status == 'in_progress' then
    return highlights.running
  end
  return highlights.queued
end

---Highlight a run line
---@param bufnr number Buffer number
---@param ns number Namespace ID
---@param line_idx number Line index (0-based)
---@param run table Run object with status and conclusion
---@param highlights table Highlight configuration
function M.highlight_run_line(bufnr, ns, line_idx, run, highlights)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]
  if not line then
    return
  end

  -- Highlight status icon
  local hl_group = M.get_status_highlight(run.status, run.conclusion, highlights)
  vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
    end_col = 1,
    hl_group = hl_group,
  })

  -- Highlight run ID (#12345)
  local id_start = line:find('#')
  local id_end = nil
  if id_start then
    id_end = line:find('%s', id_start)
    if id_end then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, id_start - 1, {
        end_col = id_end - 1,
        hl_group = highlights.run_id,
      })
    end
  end

  -- Highlight branch name (before first colon)
  if id_end then
    local branch_end = line:find(':', id_end)
    if branch_end then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, id_end, {
        end_col = branch_end,
        hl_group = highlights.branch,
      })
    end
  end

  -- Highlight time info (last two columns)
  local time_pattern = '%d+[smhdwy]+ ago'
  local time_start = line:find(time_pattern)
  if time_start then
    vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, time_start - 1, {
      end_line = line_idx,
      end_col = #line,
      hl_group = highlights.time,
    })
  end
end

---Highlight a job line
---@param bufnr number Buffer number
---@param ns number Namespace ID
---@param line_idx number Line index (0-based)
---@param job table Job object with status and conclusion
---@param highlights table Highlight configuration
function M.highlight_job_line(bufnr, ns, line_idx, job, highlights)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]
  if not line then
    return
  end

  -- Highlight job status icon
  local hl_group = M.get_status_highlight(job.status, job.conclusion, highlights)
  vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 2, {
    end_col = 3,
    hl_group = hl_group,
  })

  -- Highlight "Job:" text
  local job_start = line:find('Job:')
  if job_start then
    vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, job_start - 1, {
      end_col = job_start + 3,
      hl_group = highlights.job_name,
    })

    -- Highlight job name
    local name_start = job_start + 5
    local time_start_job = line:find('%d+[smh]', name_start)
    local running_start = line:find('%(running%)', name_start)
    local name_end = time_start_job or running_start or #line
    if name_start < name_end then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, name_start - 1, {
        end_col = name_end - 1,
        hl_group = highlights.job_name,
      })
    end

    -- Highlight duration/status
    if time_start_job or running_start then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, name_end - 1, {
        end_col = #line,
        hl_group = highlights.time,
      })
    end
  end
end

---Highlight a step line
---@param bufnr number Buffer number
---@param ns number Namespace ID
---@param line_idx number Line index (0-based)
---@param step table Step object with status and conclusion
---@param highlights table Highlight configuration
function M.highlight_step_line(bufnr, ns, line_idx, step, highlights)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]
  if not line then
    return
  end

  -- format_step layout (per `formatter.format_step`):
  --   '    {prefix} {icon} {name}  {duration}'
  -- where {prefix} is the 2-char `├─` or `└─` (each char is 3 bytes in UTF-8)
  -- and {icon} is a single status character (1-3 bytes). Use `vim.str_byteindex`
  -- so column offsets are correct regardless of whether characters are multibyte.
  local PREFIX_START_CHAR = 4 -- after 4 leading spaces
  local PREFIX_END_CHAR = 6 -- exclusive: after `├─`
  local ICON_START_CHAR = 7 -- after one space
  local ICON_END_CHAR = 8 -- exclusive: after the icon character
  local NAME_START_CHAR = 9 -- after one space

  local ok_prefix, prefix_start_byte = pcall(vim.str_byteindex, line, PREFIX_START_CHAR)
  local ok_prefix_end, prefix_end_byte = pcall(vim.str_byteindex, line, PREFIX_END_CHAR)
  if not (ok_prefix and ok_prefix_end) then
    return
  end

  -- Highlight tree prefix (├─ or └─) over its full byte width
  vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, prefix_start_byte, {
    end_col = prefix_end_byte,
    hl_group = highlights.tree_prefix,
  })

  -- Highlight step status icon over its full byte width
  local ok_icon_start, icon_start_byte = pcall(vim.str_byteindex, line, ICON_START_CHAR)
  local ok_icon_end, icon_end_byte = pcall(vim.str_byteindex, line, ICON_END_CHAR)
  if ok_icon_start and ok_icon_end then
    local hl_group = M.get_status_highlight(step.status, step.conclusion, highlights)
    vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, icon_start_byte, {
      end_col = icon_end_byte,
      hl_group = hl_group,
    })
  end

  -- Highlight step name (search for duration/status markers in BYTE positions)
  local ok_name_start, name_start_byte = pcall(vim.str_byteindex, line, NAME_START_CHAR)
  if not ok_name_start then
    return
  end

  -- search starts at 1-indexed byte (name_start_byte + 1)
  local search_from = name_start_byte + 1
  local time_start_step = line:find('%d+[smh]', search_from)
  local skipped_start = line:find('%(skipped%)', search_from)
  local running_start_step = line:find('%(running%)', search_from)
  -- name_end_pos is 1-indexed byte position of the first byte of the marker;
  -- the name ends two bytes earlier (one for the marker char, one for the gap space).
  local name_end_pos = time_start_step or skipped_start or running_start_step

  if name_end_pos then
    if name_start_byte < name_end_pos - 2 then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, name_start_byte, {
        end_col = name_end_pos - 2,
        hl_group = highlights.step_name,
      })
    end
    vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, name_end_pos - 1, {
      end_col = #line,
      hl_group = highlights.time,
    })
  else
    if name_start_byte < #line then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, name_start_byte, {
        end_col = #line,
        hl_group = highlights.step_name,
      })
    end
  end
end

---Highlight footer line
---@param bufnr number Buffer number
---@param ns number Namespace ID
---@param line_idx number Line index (0-based)
---@param highlights table Highlight configuration
function M.highlight_footer(bufnr, ns, line_idx, highlights)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]
  if not line then
    return
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
    end_line = line_idx,
    end_col = #line,
    hl_group = highlights.time,
  })
end

---Apply syntax highlighting to buffer lines
---@param bufnr number Buffer number
---@param runs table[] List of run objects
---@param highlights table Highlight configuration
function M.apply_highlights(bufnr, runs, highlights)
  local ns = vim.api.nvim_create_namespace('github-actions-history')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Highlight each run line and expanded content
  -- First run starts at line 2 (0-based) due to keymap help text and empty line at the top
  local current_line = 2
  for _, run in ipairs(runs) do
    M.highlight_run_line(bufnr, ns, current_line, run, highlights)
    current_line = current_line + 1

    -- Highlight expanded jobs and steps
    if run.expanded and run.jobs then
      for _, job in ipairs(run.jobs) do
        M.highlight_job_line(bufnr, ns, current_line, job, highlights)
        current_line = current_line + 1

        -- Highlight steps
        if job.steps then
          for _, step in ipairs(job.steps) do
            M.highlight_step_line(bufnr, ns, current_line, step, highlights)
            current_line = current_line + 1
          end
        end
      end
    end
  end
end

return M
