-- Test for gh CLI wrapper module

---@diagnostic disable: need-check-nil, undefined-field, param-type-mismatch

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local fixture = require('spec.helpers.fixture')

describe('github', function()
  ---@type Github
  local github = require('github-actions.github')

  describe('parse_response', function()
    it('should parse valid JSON response', function()
      local json_str = fixture.load('gh_api_releases_latest_success')
      local result, err = github.parse_response(json_str)

      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.equals('table', type(result))
    end)

    it('should handle invalid JSON gracefully', function()
      local invalid_json = '{ invalid json }'
      local result, err = github.parse_response(invalid_json)

      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.is_string(err)
    end)

    it('should handle empty string', function()
      local result, err = github.parse_response('')

      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)

  describe('extract_version', function()
    it('should extract version from release data', function()
      local json_str = fixture.load('gh_api_releases_latest_success')
      local data = github.parse_response(json_str)
      local version = github.extract_version(data)

      assert.is_not_nil(version)
      assert.equals('v5.0.0', version)
    end)

    it('should handle missing tag_name field', function()
      local data = { name = 'v5.0.0' }
      local version = github.extract_version(data)

      assert.is_nil(version)
    end)

    it('should handle nil data', function()
      local version = github.extract_version(nil)

      assert.is_nil(version)
    end)
  end)

  describe('is_available', function()
    it('should check if gh command exists', function()
      local available = github.is_available()

      -- available should be boolean
      assert.equals('boolean', type(available))
    end)
  end)

  describe('extract_latest_tag', function()
    it('should extract latest tag from tags data', function()
      local json_str = fixture.load('gh_api_tags_success')
      local data = github.parse_response(json_str)
      local version = github.extract_latest_tag(data)

      assert.is_not_nil(version)
      assert.equals('v1.0.1', version)
    end)

    it('should handle empty tags array', function()
      local data = {}
      local version = github.extract_latest_tag(data)

      assert.is_nil(version)
    end)

    it('should handle nil data', function()
      local version = github.extract_latest_tag(nil)

      assert.is_nil(version)
    end)

    it('should handle tags without name field', function()
      local data = {
        { commit = { sha = 'abc123' } },
      }
      local version = github.extract_latest_tag(data)

      assert.is_nil(version)
    end)
  end)

  describe('dispatch_workflow', function()
    it('should return error when gh command is not available', function()
      local stub = require('luassert.stub')
      local called = false
      local err_msg = nil

      -- Stub gh availability check
      stub(github, 'is_available')
      github.is_available.returns(false)

      github.dispatch_workflow('ci.yml', 'main', {}, function(_, err)
        called = true
        err_msg = err
      end)

      assert.is_true(called)
      assert.is_not_nil(err_msg)
      assert.equals('gh command not found', err_msg)

      -- Verify stub was called
      assert.stub(github.is_available).was_called()
    end)

    it('should build correct command without inputs', function()
      local stub = require('luassert.stub')
      local captured_cmd = nil

      -- Stub is_available to return true
      stub(github, 'is_available')
      github.is_available.returns(true)

      -- Stub vim.system
      stub(vim, 'system')
      vim.system.invokes(function(cmd, _, callback)
        captured_cmd = cmd
        callback({ code = 0, stdout = '', stderr = '' })
      end)

      local called = false
      github.dispatch_workflow('ci.yml', 'main', {}, function()
        called = true
      end)

      assert.is_not_nil(captured_cmd)
      assert.same({ 'gh', 'workflow', 'run', 'ci.yml', '--ref', 'main' }, captured_cmd)
      assert.is_true(called)

      -- Verify stubs were called
      assert.stub(github.is_available).was_called()
      assert.stub(vim.system).was_called()
    end)

    it('should build correct command with inputs', function()
      local stub = require('luassert.stub')
      local captured_cmd = nil

      -- Stub is_available to return true
      stub(github, 'is_available')
      github.is_available.returns(true)

      -- Stub vim.system
      stub(vim, 'system')
      vim.system.invokes(function(cmd, _, callback)
        captured_cmd = cmd
        callback({ code = 0, stdout = '', stderr = '' })
      end)

      local inputs = {
        { name = 'version', value = '1.0.0' },
        { name = 'environment', value = 'production' },
      }

      github.dispatch_workflow('deploy.yml', 'main', inputs, function() end)

      assert.is_not_nil(captured_cmd)
      assert.same({
        'gh',
        'workflow',
        'run',
        'deploy.yml',
        '--ref',
        'main',
        '-f',
        'version=1.0.0',
        '-f',
        'environment=production',
      }, captured_cmd)

      -- Verify stubs were called
      assert.stub(github.is_available).was_called()
      assert.stub(vim.system).was_called()
    end)

    it('should handle workflow dispatch failure', function()
      local stub = require('luassert.stub')

      -- Stub is_available to return true
      stub(github, 'is_available')
      github.is_available.returns(true)

      -- Stub vim.system to simulate failure
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 1, stdout = '', stderr = 'workflow not found' })
      end)

      local called = false
      local success_result = nil
      local err_msg = nil

      github.dispatch_workflow('nonexistent.yml', 'main', {}, function(success, err)
        called = true
        success_result = success
        err_msg = err
      end)

      assert.is_true(called)
      assert.is_false(success_result)
      assert.is_not_nil(err_msg)
      assert.matches('workflow not found', err_msg)

      -- Verify stubs were called
      assert.stub(github.is_available).was_called()
      assert.stub(vim.system).was_called()
    end)

    it('should handle successful workflow dispatch', function()
      local stub = require('luassert.stub')

      -- Stub is_available to return true
      stub(github, 'is_available')
      github.is_available.returns(true)

      -- Stub vim.system to simulate success
      stub(vim, 'system')
      vim.system.invokes(function(_, _, callback)
        callback({ code = 0, stdout = '', stderr = '' })
      end)

      local called = false
      local success_result = nil

      github.dispatch_workflow('ci.yml', 'main', {}, function(success)
        called = true
        success_result = success
      end)

      assert.is_true(called)
      assert.is_true(success_result)

      -- Verify stubs were called
      assert.stub(github.is_available).was_called()
      assert.stub(vim.system).was_called()
    end)
  end)
end)
