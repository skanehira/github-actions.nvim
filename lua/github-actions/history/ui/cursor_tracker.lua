---@class CursorTracker
local M = {}

---Get run index from cursor line
---@param bufnr number Buffer number
---@param runs table[] List of run objects
---@return number|nil run_idx Run index (1-based) or nil if not on a run line
function M.get_run_at_cursor(bufnr, runs)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_idx = cursor[1] - 1 -- Convert to 0-based

  if not runs then
    return nil
  end

  -- Find which run this line belongs to
  local current_line = 0 -- First run starts at line 0 (0-based)
  for run_idx, run in ipairs(runs) do
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
---@param runs table[] List of run objects
---@return number|nil run_idx Index of the run
---@return number|nil job_idx Index of the job
function M.get_job_at_cursor(bufnr, runs)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_idx = cursor[1] - 1

  if not runs then
    return nil, nil
  end

  local current_line = 0 -- First run starts at line 0

  for run_idx, run in ipairs(runs) do
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

return M
