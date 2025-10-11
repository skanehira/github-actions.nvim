-- Test for gh CLI wrapper module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local fixture = require('spec.helpers.fixture')

describe('github', function()
  ---@type Github
  local github

  before_each(function()
    github = require('github-actions.github')
  end)

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
end)
