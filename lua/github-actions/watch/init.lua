local picker = require('github-actions.shared.picker')
local api = require('github-actions.history.api')
local filter = require('github-actions.watch.filter')
local run_picker = require('github-actions.watch.run_picker')
local config_module = require('github-actions.config')
local buffer_utils = require('github-actions.shared.buffer_utils')

local M = {}

---Launch gh run watch in terminal
---@param run_id number Run ID
---@param open_mode? string How to open terminal: "tab", "vsplit", "split", "current", "float"
---@param window_options? table<string, any> Window options for float mode
---@param window_geometry_options? FloatWindowOptions
---@param workflow_file? string Workflow filename for display title
local function launch_watch_terminal(run_id, open_mode, window_options, window_geometry_options, workflow_file)
  local geometry_options = window_geometry_options or {}
  local title = geometry_options.title or workflow_file and ('Watch - ' .. workflow_file) or ('gh run watch ' .. run_id)
  geometry_options = vim.tbl_extend('keep', window_geometry_options or {}, { title = title })

  buffer_utils.open_terminal(open_mode or 'tab', { 'gh', 'run', 'watch', tostring(run_id) }, {
    window_options = window_options,
    window_geometry_options = geometry_options,
  })
end

---Entry point for workflow watch functionality
---@param opts? WatchOptions Configuration options
function M.watch_workflow(opts)
  opts = opts or {}

  -- Get default configuration
  local defaults = config_module.get_defaults()
  local icons = config_module.merge_icons(defaults.history.icons, opts.icons)
  local open_mode = opts.open_mode or 'tab'
  local window_options = opts.window_options or {}
  local window_geometry_options = opts.window_geometry_options

  -- Step 1: Select workflow file
  picker.select_workflow_files({
    prompt = 'Select workflow to watch:',
    on_select = function(selected_paths)
      if not selected_paths or #selected_paths == 0 then
        return
      end

      -- Extract filename from path
      local workflow_path = selected_paths[1]
      local workflow_file = workflow_path:match('[^/]+%.ya?ml$')

      -- Step 2: Fetch runs for selected workflow
      api.fetch_runs(workflow_file, function(runs, err)
        if err then
          vim.notify('[GitHub Actions] ' .. err, vim.log.levels.ERROR)
          return
        end

        -- Step 3: Filter running workflows
        local running_runs = filter.filter_running_runs(runs)

        -- Step 4: Handle based on count
        if #running_runs == 0 then
          vim.notify('[GitHub Actions] No running workflows found', vim.log.levels.INFO)
        elseif #running_runs == 1 then
          -- Single running workflow - launch directly
          launch_watch_terminal(
            running_runs[1].databaseId,
            open_mode,
            window_options,
            window_geometry_options,
            workflow_file
          )
        else
          -- Multiple running workflows - show picker
          run_picker.select_run({
            prompt = 'Select workflow run to watch:',
            runs = running_runs,
            icons = icons,
            on_select = function(run)
              launch_watch_terminal(run.databaseId, open_mode, window_options, window_geometry_options, workflow_file)
            end,
          })
        end
      end)
    end,
  })
end

return M
