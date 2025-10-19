local formatter = require('github-actions.history.ui.formatter')

local M = {}

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

  return bufnr, winnr
end

---Set up keymaps for the buffer
---@param bufnr number Buffer number
function M.setup_keymaps(bufnr)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Close buffer with 'q'
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
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
local function apply_highlights(bufnr, runs)
  local ns = vim.api.nvim_create_namespace('github-actions-history')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Highlight header (line 0)
  vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
    end_line = 0,
    end_col = #vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1],
    hl_group = 'GitHubActionsHistoryHeader',
  })

  -- Highlight separator (line 1)
  vim.api.nvim_buf_set_extmark(bufnr, ns, 1, 0, {
    end_line = 1,
    end_col = #vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1],
    hl_group = 'GitHubActionsHistorySeparator',
  })

  -- Highlight each run line (starting from line 3)
  for i, run in ipairs(runs) do
    local line_idx = i + 2 -- Header + separator + empty line

    -- Highlight status icon
    local hl_group = 'GitHubActionsHistoryQueued'
    if run.status == 'completed' then
      if run.conclusion == 'success' then
        hl_group = 'GitHubActionsHistorySuccess'
      elseif run.conclusion == 'failure' then
        hl_group = 'GitHubActionsHistoryFailure'
      elseif run.conclusion == 'cancelled' or run.conclusion == 'skipped' then
        hl_group = 'GitHubActionsHistoryCancelled'
      end
    elseif run.status == 'in_progress' then
      hl_group = 'GitHubActionsHistoryRunning'
    end
    vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
      end_col = 1,
      hl_group = hl_group,
    })

    -- Highlight run ID (#12345)
    local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]
    local id_start = line:find('#')
    local id_end = nil
    if id_start then
      id_end = line:find('%s', id_start)
      if id_end then
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, id_start - 1, {
          end_col = id_end - 1,
          hl_group = 'GitHubActionsHistoryRunId',
        })
      end
    end

    -- Highlight branch name (before first colon)
    if id_end then
      local branch_end = line:find(':', id_end)
      if branch_end then
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, id_end, {
          end_col = branch_end,
          hl_group = 'GitHubActionsHistoryBranch',
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
        hl_group = 'GitHubActionsHistoryTime',
      })
    end
  end

  -- Highlight footer
  local footer_line = 3 + #runs + 1
  local footer_text = vim.api.nvim_buf_get_lines(bufnr, footer_line, footer_line + 1, false)[1]
  vim.api.nvim_buf_set_extmark(bufnr, ns, footer_line, 0, {
    end_line = footer_line,
    end_col = #footer_text,
    hl_group = 'GitHubActionsHistoryTime',
  })
end

---Render run list in the buffer
---@param bufnr number Buffer number
---@param runs table[] List of run objects
---@param custom_icons? HistoryIcons Custom icon configuration
function M.render(bufnr, runs, custom_icons)
  -- Make buffer modifiable temporarily
  vim.bo[bufnr].modifiable = true

  local lines = {}

  -- Add header
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  table.insert(lines, bufname)

  -- Get window width for separator
  local winnr = vim.fn.bufwinid(bufnr)
  local width = winnr ~= -1 and vim.api.nvim_win_get_width(winnr) or 80
  table.insert(lines, string.rep('━', width))
  table.insert(lines, '')

  if #runs == 0 then
    table.insert(lines, 'No workflow runs found.')
  else
    -- Add each run
    for _, run in ipairs(runs) do
      table.insert(lines, formatter.format_run(run, nil, custom_icons))
    end
  end

  table.insert(lines, '')
  table.insert(lines, 'Press q to close')

  -- Set buffer lines
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights (highlight groups are already setup in init.lua)
  setup_buffer_highlights(bufnr)
  if #runs > 0 then
    apply_highlights(bufnr, runs)
  end

  -- Make buffer read-only again
  vim.bo[bufnr].modifiable = false
end

return M
