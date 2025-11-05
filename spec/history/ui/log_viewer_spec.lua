dofile('spec/minimal_init.lua')

describe('history.ui.log_viewer', function()
  local log_viewer = require('github-actions.history.ui.log_viewer')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('can_view_logs', function()
    it('should return false when run is in_progress', function()
      local run = {
        status = 'in_progress',
        databaseId = 12345,
      }
      local job = {
        status = 'completed',
        conclusion = 'success',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('still running') ~= nil)
    end)

    it('should return false when run is queued', function()
      local run = {
        status = 'queued',
        databaseId = 12345,
      }
      local job = {
        status = 'completed',
        conclusion = 'success',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('queued') ~= nil)
    end)

    it('should return false when job is in_progress', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
      }
      local job = {
        status = 'in_progress',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('still running') ~= nil)
    end)

    it('should return false when job is queued', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
      }
      local job = {
        status = 'queued',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('queued') ~= nil)
    end)

    it('should return true when both run and job are completed', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
      }
      local job = {
        status = 'completed',
        conclusion = 'success',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_true(can_view)
      assert.is_nil(message)
    end)
  end)

  describe('view_logs', function()
    -- Note: This function has external dependencies (logs_buffer, history.fetch_logs)
    -- so we only test the validation logic here
    it('should not proceed when run is nil', function()
      local result = log_viewer.view_logs(nil, nil)
      assert.is_nil(result)
    end)

    it('should not proceed when job is nil', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
        jobs = {},
      }
      local result = log_viewer.view_logs(run, nil)
      assert.is_nil(result)
    end)
  end)
end)
