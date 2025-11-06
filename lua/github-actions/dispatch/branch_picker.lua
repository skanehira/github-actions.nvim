local git = require('github-actions.lib.git')

local M = {}

---Options for branch picker
---@class BranchPickerOptions
---@field prompt string Prompt text to display
---@field on_select function(selected: string) Callback with selected branch

---Select branch using telescope or vim.ui.select
---@param opts BranchPickerOptions Picker options
function M.select_branch(opts)
  -- Get remote branches
  local branches = git.get_remote_branches()
  if #branches == 0 then
    vim.notify('[GitHub Actions] No remote branches found', vim.log.levels.ERROR)
    return
  end

  -- Try to use telescope for better UX
  local has_telescope, _ = pcall(require, 'telescope.builtin')
  local has_telescope_actions, telescope_actions = pcall(require, 'telescope.actions')
  local has_telescope_state, telescope_state = pcall(require, 'telescope.actions.state')

  if has_telescope and has_telescope_actions and has_telescope_state then
    -- Use telescope native picker with preview support
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values

    pickers
      .new({}, {
        prompt_title = opts.prompt,
        finder = finders.new_table({
          results = branches,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry,
              ordinal = entry,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          -- Add preview scrolling keymaps
          map('i', '<C-u>', telescope_actions.preview_scrolling_up)
          map('i', '<C-d>', telescope_actions.preview_scrolling_down)
          map('n', '<C-u>', telescope_actions.preview_scrolling_up)
          map('n', '<C-d>', telescope_actions.preview_scrolling_down)

          telescope_actions.select_default:replace(function()
            local selection = telescope_state.get_selected_entry()
            telescope_actions.close(prompt_bufnr)

            if selection then
              opts.on_select(selection.value)
            end
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(branches, {
      prompt = opts.prompt,
    }, function(selected)
      if not selected then
        return
      end

      opts.on_select(selected)
    end)
  end
end

return M
