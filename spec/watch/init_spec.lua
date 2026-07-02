dofile('spec/minimal_init.lua')

---@diagnostic disable: undefined-field, need-check-nil

describe('watch.init', function()
  local watch
  local picker
  local api
  local filter
  local run_picker
  local poll

  local function flush_scheduled()
    vim.wait(0, function()
      return false
    end)
  end

  local mocks = {}

  local function setup_mock(target, key, mock_fn)
    table.insert(mocks, { target = target, key = key, original = target[key] })
    target[key] = mock_fn
  end

  before_each(function()
    package.loaded['github-actions.watch'] = nil
    package.loaded['github-actions.shared.picker'] = nil
    package.loaded['github-actions.history.api'] = nil
    package.loaded['github-actions.watch.filter'] = nil
    package.loaded['github-actions.watch.run_picker'] = nil
    package.loaded['github-actions.watch.poll'] = nil

    watch = require('github-actions.watch')
    picker = require('github-actions.shared.picker')
    api = require('github-actions.history.api')
    filter = require('github-actions.watch.filter')
    run_picker = require('github-actions.watch.run_picker')
    poll = require('github-actions.watch.poll')
  end)

  after_each(function()
    for _, mock in ipairs(mocks) do
      mock.target[mock.key] = mock.original
    end
    mocks = {}
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
      local jobstart_args = nil
      setup_mock(vim.fn, 'jobstart', function(cmd, _)
        jobstart_args = cmd
        return 1
      end)

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
      for _, call in ipairs(cmd_calls) do
        if call.vals[1]:match('tabnew') then
          found_tabnew = true
        end
      end
      assert.is_true(found_tabnew, 'Should open new tab')
      assert.is_not_nil(jobstart_args)
      assert.equals('gh', jobstart_args[1])
      assert.equals('run', jobstart_args[2])
      assert.equals('watch', jobstart_args[3])
      assert.equals('12345', jobstart_args[4])

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
      local jobstart_args = nil
      setup_mock(vim.fn, 'jobstart', function(cmd, _)
        jobstart_args = cmd
        return 1
      end)

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
        opts.on_select(opts.runs[2])
      end)

      watch.watch_workflow({})
      flush_scheduled()

      assert.is_not_nil(jobstart_args)
      assert.equals('gh', jobstart_args[1])
      assert.equals('run', jobstart_args[2])
      assert.equals('watch', jobstart_args[3])
      assert.equals('200', jobstart_args[4])

      picker_stub:revert()
      api_stub:revert()
      run_picker_stub:revert()
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

    it('should open terminal in float window when open_mode is float', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')

      local captured_float_opts = nil
      setup_mock(vim.api, 'nvim_open_win', function(bufnr, _, opts)
        captured_float_opts = opts
        return 1001
      end)

      local jobstart_args = nil
      setup_mock(vim.fn, 'jobstart', function(cmd, _)
        jobstart_args = cmd
        return 1
      end)

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

      watch.watch_workflow({ open_mode = 'float' })
      flush_scheduled()

      assert.is_not_nil(captured_float_opts)
      assert.equals('editor', captured_float_opts.relative)
      assert.equals('minimal', captured_float_opts.style)
      assert.equals('rounded', captured_float_opts.border)
      assert.equals('Watch - ci.yml', captured_float_opts.title)

      assert.is_not_nil(jobstart_args)
      assert.equals('gh', jobstart_args[1])
      assert.equals('run', jobstart_args[2])
      assert.equals('watch', jobstart_args[3])
      assert.equals('12345', jobstart_args[4])

      picker_stub:revert()
      api_stub:revert()
    end)

    it('should respect custom window_options for float mode', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local api_stub = stub(api, 'fetch_runs')

      local captured_float_opts = nil
      setup_mock(vim.api, 'nvim_open_win', function(bufnr, _, opts)
        captured_float_opts = opts
        return 1001
      end)
      setup_mock(vim.fn, 'jobstart', function(_)
        return 1
      end)

      picker_stub.invokes(function(opts)
        opts.on_select({ '.github/workflows/ci.yml' })
      end)

      api_stub.invokes(function(workflow_file, callback)
        callback({
          {
            databaseId = 999,
            status = 'in_progress',
            headBranch = 'main',
            displayTitle = 'CI',
            createdAt = '2025-11-14T10:00:00Z',
          },
        }, nil)
      end)

      watch.watch_workflow({
        open_mode = 'float',
        window_options = {},
        window_geometry_options = {
          width = 60,
          height = 30,
          row = 5,
          col = 10,
        },
      })
      flush_scheduled()

      assert.is_not_nil(captured_float_opts)
      assert.equals(60, captured_float_opts.width)
      assert.equals(30, captured_float_opts.height)
      assert.equals(5, captured_float_opts.row)
      assert.equals(10, captured_float_opts.col)

      picker_stub:revert()
      api_stub:revert()
    end)
  end)

  describe('watch_dispatched_workflow', function()
    it('should poll runs for the given workflow without showing file picker', function()
      local picker_stub = stub(picker, 'select_workflow_files')
      local poll_stub = stub(poll, 'poll_running_runs')

      watch.watch_dispatched_workflow('ci.yml')
      flush_scheduled()

      assert.stub(picker_stub).was_not_called()
      assert.stub(poll_stub).was_called(1)
      assert.stub(poll_stub).was_called_with('ci.yml', nil, match.is_function())

      picker_stub:revert()
      poll_stub:revert()
    end)

    it('should launch terminal directly when poll finds single running run', function()
      local poll_stub = stub(poll, 'poll_running_runs')
      local cmd_stub = stub(vim, 'cmd')
      local jobstart_args = nil
      setup_mock(vim.fn, 'jobstart', function(cmd, _)
        jobstart_args = cmd
        return 1
      end)

      poll_stub.invokes(function(_, _, callback)
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

      watch.watch_dispatched_workflow('ci.yml')
      flush_scheduled()

      local found_tabnew = false
      for _, call in ipairs(cmd_stub.calls) do
        if call.vals[1]:match('tabnew') then
          found_tabnew = true
        end
      end
      assert.is_true(found_tabnew, 'Should open new tab')
      assert.same({ 'gh', 'run', 'watch', '12345' }, jobstart_args)

      poll_stub:revert()
      cmd_stub:revert()
    end)

    it('should show run picker when poll finds multiple running runs', function()
      local poll_stub = stub(poll, 'poll_running_runs')
      local run_picker_stub = stub(run_picker, 'select_run')

      poll_stub.invokes(function(_, _, callback)
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

      watch.watch_dispatched_workflow('ci.yml')
      flush_scheduled()

      assert.stub(run_picker_stub).was_called(1)
      local call_args = run_picker_stub.calls[1].vals[1]
      assert.equals(2, #call_args.runs)

      poll_stub:revert()
      run_picker_stub:revert()
    end)

    it('should show info message when poll finds no running runs', function()
      local poll_stub = stub(poll, 'poll_running_runs')
      local notify_stub = stub(vim, 'notify')

      poll_stub.invokes(function(_, _, callback)
        callback({}, nil)
      end)

      watch.watch_dispatched_workflow('ci.yml')
      flush_scheduled()

      assert
        .stub(notify_stub)
        .was_called_with('[GitHub Actions] No running workflow runs found for ci.yml', vim.log.levels.INFO)

      poll_stub:revert()
      notify_stub:revert()
    end)

    it('should show error message when poll fails', function()
      local poll_stub = stub(poll, 'poll_running_runs')
      local notify_stub = stub(vim, 'notify')

      poll_stub.invokes(function(_, _, callback)
        callback(nil, 'API error: rate limit exceeded')
      end)

      watch.watch_dispatched_workflow('ci.yml')
      flush_scheduled()

      assert.stub(notify_stub).was_called_with('[GitHub Actions] API error: rate limit exceeded', vim.log.levels.ERROR)

      poll_stub:revert()
      notify_stub:revert()
    end)
  end)
end)
