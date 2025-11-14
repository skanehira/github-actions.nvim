dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field, need-check-nil

describe('watch.init', function()
  local watch
  local picker
  local api
  local filter
  local run_picker

  local function flush_scheduled()
    vim.wait(0, function()
      return false
    end)
  end

  before_each(function()
    package.loaded['github-actions.watch'] = nil
    package.loaded['github-actions.shared.picker'] = nil
    package.loaded['github-actions.history.api'] = nil
    package.loaded['github-actions.watch.filter'] = nil
    package.loaded['github-actions.watch.run_picker'] = nil

    watch = require('github-actions.watch')
    picker = require('github-actions.shared.picker')
    api = require('github-actions.history.api')
    filter = require('github-actions.watch.filter')
    run_picker = require('github-actions.watch.run_picker')
  end)

  describe('watch_workflow', function()
    it('should call workflow file picker', function()
      local picker_stub = stub(picker, 'select_workflow_files')

      watch.watch_workflow({})
      flush_scheduled()

      assert.stub(picker_stub).was_called(1)
      picker_stub:revert()
    end)

    it('should fetch runs after workflow selection', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      watch.watch_workflow({})
      flush_scheduled()

      assert.stub(api_stub).was_called(1)
      assert.stub(api_stub).was_called_with('ci.yml', match.is_function())

      picker_stub:revert()
      api_stub:revert()
    end)

    it('should show info message when no running workflows', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')
      local notify_stub = stub(vim, 'notify')

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      api_stub.invokes(function(workflow_file, callback)
        callback({
          {
            databaseId = 1,
            status = 'completed',
            headBranch = 'main',
            displayTitle = 'CI',
            createdAt = '2025-11-14T10:00:00Z',
          },
        }, nil)
      end)

      watch.watch_workflow({})
      flush_scheduled()

      assert.stub(notify_stub).was_called()
      local call_args = notify_stub.calls[1].vals
      assert.is_not_nil(call_args[1]:match('No running workflows found'))

      picker_stub:revert()
      api_stub:revert()
      notify_stub:revert()
    end)

    it('should launch terminal directly when single running workflow', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')
      local cmd_stub = stub(vim, 'cmd')

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      api_stub.invokes(function(workflow_file, callback)
        callback({
          {
            databaseId = 12345,
            status = 'in_progress',
            headBranch = 'main',
            displayTitle = 'CI',
            createdAt = '2025-11-14T10:00:00Z',
          },
        }, nil)
      end)

      watch.watch_workflow({})
      flush_scheduled()

      -- Should open terminal in new tab with gh run watch
      assert.stub(cmd_stub).was_called()
      local cmd_calls = cmd_stub.calls
      local found_tabnew = false
      local found_terminal = false
      for _, call in ipairs(cmd_calls) do
        local arg = call.vals[1]
        if arg:match('tabnew') then
          found_tabnew = true
        end
        if arg:match('terminal') and arg:match('gh run watch') and arg:match('12345') then
          found_terminal = true
        end
      end
      assert.is_true(found_tabnew, 'Should open new tab')
      assert.is_true(found_terminal, 'Should launch gh run watch terminal')

      picker_stub:revert()
      api_stub:revert()
      cmd_stub:revert()
    end)

    it('should show run picker when multiple running workflows', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')
      local run_picker_stub = stub(run_picker, 'select_run')

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      api_stub.invokes(function(workflow_file, callback)
        callback({
          {
            databaseId = 1,
            status = 'in_progress',
            headBranch = 'main',
            displayTitle = 'CI Main',
            createdAt = '2025-11-14T10:00:00Z',
          },
          {
            databaseId = 2,
            status = 'queued',
            headBranch = 'develop',
            displayTitle = 'CI Develop',
            createdAt = '2025-11-14T09:00:00Z',
          },
        }, nil)
      end)

      watch.watch_workflow({})
      flush_scheduled()

      assert.stub(run_picker_stub).was_called(1)
      local call_args = run_picker_stub.calls[1].vals[1]
      assert.is_not_nil(call_args.runs)
      assert.equals(2, #call_args.runs)

      picker_stub:revert()
      api_stub:revert()
      run_picker_stub:revert()
    end)

    it('should launch terminal after run selection from picker', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')
      local run_picker_stub = stub(run_picker, 'select_run')
      local cmd_stub = stub(vim, 'cmd')

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      api_stub.invokes(function(workflow_file, callback)
        callback({
          {
            databaseId = 100,
            status = 'in_progress',
            headBranch = 'main',
            displayTitle = 'CI Main',
            createdAt = '2025-11-14T10:00:00Z',
          },
          {
            databaseId = 200,
            status = 'queued',
            headBranch = 'develop',
            displayTitle = 'CI Develop',
            createdAt = '2025-11-14T09:00:00Z',
          },
        }, nil)
      end)

      run_picker_stub.invokes(function(opts)
        -- User selects second run
        opts.on_select(opts.runs[2])
      end)

      watch.watch_workflow({})
      flush_scheduled()

      -- Should launch terminal with selected run ID
      assert.stub(cmd_stub).was_called()
      local cmd_calls = cmd_stub.calls
      local found_terminal = false
      for _, call in ipairs(cmd_calls) do
        local arg = call.vals[1]
        if arg:match('terminal') and arg:match('gh run watch') and arg:match('200') then
          found_terminal = true
        end
      end
      assert.is_true(found_terminal, 'Should launch terminal with run ID 200')

      picker_stub:revert()
      api_stub:revert()
      run_picker_stub:revert()
      cmd_stub:revert()
    end)

    it('should show error when API call fails', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')
      local notify_stub = stub(vim, 'notify')

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      api_stub.invokes(function(workflow_file, callback)
        callback(nil, 'API error: rate limit exceeded')
      end)

      watch.watch_workflow({})
      flush_scheduled()

      assert.stub(notify_stub).was_called()
      local call_args = notify_stub.calls[1].vals
      assert.is_not_nil(call_args[1]:match('[GitHub Actions]'))
      assert.is_not_nil(call_args[1]:match('API error'))
      assert.equals(vim.log.levels.ERROR, call_args[2])

      picker_stub:revert()
      api_stub:revert()
      notify_stub:revert()
    end)

    it('should use default icons when no config provided', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')
      local run_picker_stub = stub(run_picker, 'select_run')

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      api_stub.invokes(function(workflow_file, callback)
        callback({
          {
            databaseId = 1,
            status = 'in_progress',
            headBranch = 'main',
            displayTitle = 'CI',
            createdAt = '2025-11-14T10:00:00Z',
          },
          {
            databaseId = 2,
            status = 'queued',
            headBranch = 'develop',
            displayTitle = 'Build',
            createdAt = '2025-11-14T09:00:00Z',
          },
        }, nil)
      end)

      watch.watch_workflow() -- No config
      flush_scheduled()

      assert.stub(run_picker_stub).was_called(1)
      local call_args = run_picker_stub.calls[1].vals[1]
      assert.is_not_nil(call_args.icons)
      assert.is_not_nil(call_args.icons.in_progress)
      assert.is_not_nil(call_args.icons.queued)

      picker_stub:revert()
      api_stub:revert()
      run_picker_stub:revert()
    end)
  end)
end)
