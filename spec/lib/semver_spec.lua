-- Test for semver module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

describe('lib.semver', function()
  ---@type Semver
  local semver = require('github-actions.lib.semver')

  describe('parse', function()
    local test_cases = {
      {
        name = 'should parse major version only',
        input = 'v3',
        expected = { 3 },
      },
      {
        name = 'should parse major.minor version',
        input = 'v3.5',
        expected = { 3, 5 },
      },
      {
        name = 'should parse full semantic version',
        input = 'v3.5.1',
        expected = { 3, 5, 1 },
      },
      {
        name = 'should parse version without v prefix',
        input = '3.5.1',
        expected = { 3, 5, 1 },
      },
      {
        name = 'should handle version with text suffix',
        input = 'v3.5.1-beta',
        expected = { 3, 5, 1 },
      },
      {
        name = 'should handle invalid version string',
        input = 'invalid',
        expected = {},
      },
      {
        name = 'should handle nil version',
        input = nil,
        expected = {},
      },
      {
        name = 'should handle empty string',
        input = '',
        expected = {},
      },
      {
        name = 'should parse version with prerelease tag',
        input = 'v3.5.1-alpha.1',
        expected = { 3, 5, 1 },
      },
      {
        name = 'should only take first 3 numeric parts',
        input = '3.5.1.999',
        expected = { 3, 5, 1 },
      },
      {
        name = 'should handle version string with only text',
        input = 'vv',
        expected = {},
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        local parts = semver.parse(tc.input)
        assert.are.same(tc.expected, parts)
      end)
    end
  end)

  describe('compare', function()
    local test_cases = {
      -- major version only
      {
        name = 'should detect outdated major version',
        current = 'v3',
        latest = 'v4.1.0',
        expected = false,
      },
      {
        name = 'should detect latest major version',
        current = 'v4',
        latest = 'v4.1.0',
        expected = true,
      },
      {
        name = 'should detect newer major version',
        current = 'v5',
        latest = 'v4.1.0',
        expected = true,
      },
      -- major.minor version
      {
        name = 'should detect outdated minor version',
        current = 'v4.0',
        latest = 'v4.1.5',
        expected = false,
      },
      {
        name = 'should detect latest minor version',
        current = 'v4.1',
        latest = 'v4.1.5',
        expected = true,
      },
      {
        name = 'should detect outdated major in major.minor',
        current = 'v3.9',
        latest = 'v4.0.0',
        expected = false,
      },
      -- full semantic version
      {
        name = 'should detect outdated patch version',
        current = 'v3.5.1',
        latest = 'v3.5.2',
        expected = false,
      },
      {
        name = 'should detect latest patch version',
        current = 'v3.5.2',
        latest = 'v3.5.2',
        expected = true,
      },
      {
        name = 'should detect outdated minor in full version',
        current = 'v3.4.5',
        latest = 'v3.5.0',
        expected = false,
      },
      {
        name = 'should detect outdated major in full version',
        current = 'v2.9.9',
        latest = 'v3.0.0',
        expected = false,
      },
      -- equal versions
      {
        name = 'should detect equal full versions',
        current = 'v3.5.1',
        latest = 'v3.5.1',
        expected = true,
      },
      {
        name = 'should detect equal versions without v prefix',
        current = '3.5.1',
        latest = '3.5.1',
        expected = true,
      },
      {
        name = 'should compare major only with equal major',
        current = 'v3',
        latest = 'v3.0.0',
        expected = true,
      },
      {
        name = 'should compare major.minor with equal major.minor',
        current = 'v3.5',
        latest = 'v3.5.0',
        expected = true,
      },
      -- newer current version
      {
        name = 'should detect newer patch version',
        current = 'v3.5.2',
        latest = 'v3.5.1',
        expected = true,
      },
      {
        name = 'should detect newer minor version',
        current = 'v3.6.0',
        latest = 'v3.5.9',
        expected = true,
      },
      {
        name = 'should detect newer major version',
        current = 'v4.0.0',
        latest = 'v3.9.9',
        expected = true,
      },
      -- latest version with fewer parts
      {
        name = 'should compare when latest has only major',
        current = 'v3.5.1',
        latest = 'v3',
        expected = true,
      },
      {
        name = 'should compare when latest has only major.minor',
        current = 'v3.5.1',
        latest = 'v3.4',
        expected = true,
      },
      {
        name = 'should detect outdated when latest major is higher',
        current = 'v3.5.1',
        latest = 'v4',
        expected = false,
      },
      -- prerelease versions
      {
        name = 'should compare prerelease versions by numeric parts only',
        current = 'v3.5.1-beta',
        latest = 'v3.5.1',
        expected = true,
      },
      {
        name = 'should detect outdated prerelease version',
        current = 'v3.5.0',
        latest = 'v3.5.1-beta',
        expected = false,
      },
      -- edge cases
      {
        name = 'should handle version without v prefix',
        current = '3.5.1',
        latest = '3.5.2',
        expected = false,
      },
      {
        name = 'should handle nil current version',
        current = nil,
        latest = 'v4.0.0',
        expected = false,
      },
      {
        name = 'should handle nil latest version',
        current = 'v4',
        latest = nil,
        expected = false,
      },
      {
        name = 'should handle both nil versions',
        current = nil,
        latest = nil,
        expected = false,
      },
      {
        name = 'should handle empty string current version',
        current = '',
        latest = 'v3.5.1',
        expected = false,
      },
      {
        name = 'should handle empty string latest version',
        current = 'v3.5.1',
        latest = '',
        expected = false,
      },
      {
        name = 'should handle invalid current version',
        current = 'invalid',
        latest = 'v3.5.1',
        expected = false,
      },
      {
        name = 'should handle invalid latest version',
        current = 'v3.5.1',
        latest = 'invalid',
        expected = false,
      },
      {
        name = 'should handle invalid versions',
        current = 'invalid',
        latest = 'also-invalid',
        expected = false,
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        local is_latest = semver.compare(tc.current, tc.latest)
        if tc.expected then
          assert.is_true(is_latest)
        else
          assert.is_false(is_latest)
        end
      end)
    end
  end)
end)
