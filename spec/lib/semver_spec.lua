-- Test for semver module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

describe('lib.semver', function()
  ---@type Semver
  local semver

  before_each(function()
    semver = require('github-actions.lib.semver')
  end)

  describe('parse', function()
    it('should parse major version only', function()
      local parts = semver.parse('v3')
      assert.are.same({ 3 }, parts)
    end)

    it('should parse major.minor version', function()
      local parts = semver.parse('v3.5')
      assert.are.same({ 3, 5 }, parts)
    end)

    it('should parse full semantic version', function()
      local parts = semver.parse('v3.5.1')
      assert.are.same({ 3, 5, 1 }, parts)
    end)

    it('should parse version without v prefix', function()
      local parts = semver.parse('3.5.1')
      assert.are.same({ 3, 5, 1 }, parts)
    end)

    it('should handle version with text suffix', function()
      local parts = semver.parse('v3.5.1-beta')
      assert.are.same({ 3, 5, 1 }, parts)
    end)

    it('should handle invalid version string', function()
      local parts = semver.parse('invalid')
      assert.are.same({}, parts)
    end)

    it('should handle nil version', function()
      local parts = semver.parse(nil)
      assert.are.same({}, parts)
    end)

    it('should handle empty string', function()
      local parts = semver.parse('')
      assert.are.same({}, parts)
    end)
  end)

  describe('compare', function()
    describe('major version only', function()
      it('should detect outdated major version', function()
        local is_latest = semver.compare('v3', 'v4.1.0')
        assert.is_false(is_latest)
      end)

      it('should detect latest major version', function()
        local is_latest = semver.compare('v4', 'v4.1.0')
        assert.is_true(is_latest)
      end)

      it('should detect newer major version', function()
        local is_latest = semver.compare('v5', 'v4.1.0')
        assert.is_true(is_latest)
      end)
    end)

    describe('major.minor version', function()
      it('should detect outdated minor version', function()
        local is_latest = semver.compare('v4.0', 'v4.1.5')
        assert.is_false(is_latest)
      end)

      it('should detect latest minor version', function()
        local is_latest = semver.compare('v4.1', 'v4.1.5')
        assert.is_true(is_latest)
      end)

      it('should detect outdated major in major.minor', function()
        local is_latest = semver.compare('v3.9', 'v4.0.0')
        assert.is_false(is_latest)
      end)
    end)

    describe('full semantic version', function()
      it('should detect outdated patch version', function()
        local is_latest = semver.compare('v3.5.1', 'v3.5.2')
        assert.is_false(is_latest)
      end)

      it('should detect latest patch version', function()
        local is_latest = semver.compare('v3.5.2', 'v3.5.2')
        assert.is_true(is_latest)
      end)

      it('should detect outdated minor in full version', function()
        local is_latest = semver.compare('v3.4.5', 'v3.5.0')
        assert.is_false(is_latest)
      end)

      it('should detect outdated major in full version', function()
        local is_latest = semver.compare('v2.9.9', 'v3.0.0')
        assert.is_false(is_latest)
      end)
    end)

    describe('edge cases', function()
      it('should handle version without v prefix', function()
        local is_latest = semver.compare('3.5.1', '3.5.2')
        assert.is_false(is_latest)
      end)

      it('should handle nil current version', function()
        local is_latest = semver.compare(nil, 'v4.0.0')
        assert.is_false(is_latest)
      end)

      it('should handle nil latest version', function()
        local is_latest = semver.compare('v4', nil)
        assert.is_false(is_latest)
      end)

      it('should handle invalid versions', function()
        local is_latest = semver.compare('invalid', 'also-invalid')
        assert.is_false(is_latest)
      end)
    end)
  end)
end)
