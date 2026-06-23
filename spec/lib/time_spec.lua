dofile('spec/minimal_init.lua')

describe('lib.time', function()
  local time = require('github-actions.lib.time')

  describe('format_relative', function()
    -- Mock current time for consistent testing
    local now = os.time({ year = 2025, month = 10, day = 19, hour = 12, min = 0, sec = 0 })

    local test_cases = {
      {
        name = 'should format seconds ago',
        timestamp = '2025-10-19T11:59:30Z',
        expected = '30s ago',
      },
      {
        name = 'should format minutes ago',
        timestamp = '2025-10-19T11:55:00Z',
        expected = '5m ago',
      },
      {
        name = 'should format hours ago',
        timestamp = '2025-10-19T10:00:00Z',
        expected = '2h ago',
      },
      {
        name = 'should format days ago',
        timestamp = '2025-10-17T12:00:00Z',
        expected = '2d ago',
      },
      {
        name = 'should format weeks ago',
        timestamp = '2025-10-05T12:00:00Z',
        expected = '2w ago',
      },
      {
        name = 'should format months ago',
        timestamp = '2025-08-19T12:00:00Z',
        expected = '2mo ago',
      },
      {
        name = 'should format years ago',
        timestamp = '2023-10-19T12:00:00Z',
        expected = '2y ago',
      },
      {
        name = 'should handle just now (less than 5 seconds)',
        timestamp = '2025-10-19T11:59:58Z',
        expected = 'just now',
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        assert.equals(tc.expected, time.format_relative(tc.timestamp, now))
      end)
    end
  end)

  describe('format_duration', function()
    local test_cases = {
      {
        name = 'should format seconds',
        seconds = 45,
        expected = '45s',
      },
      {
        name = 'should format minutes and seconds',
        seconds = 125,
        expected = '2m 5s',
      },
      {
        name = 'should format hours, minutes and seconds',
        seconds = 3665,
        expected = '1h 1m 5s',
      },
      {
        name = 'should format only hours and minutes (no seconds)',
        seconds = 3600,
        expected = '1h 0m 0s',
      },
      {
        name = 'should format zero duration',
        seconds = 0,
        expected = '0s',
      },
      {
        name = 'should format large duration',
        seconds = 7384,
        expected = '2h 3m 4s',
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        assert.equals(tc.expected, time.format_duration(tc.seconds))
      end)
    end
  end)

  describe('parse_iso8601', function()
    it('should parse ISO 8601 timestamp to unix timestamp', function()
      local timestamp = '2025-10-19T12:00:00Z'
      local result = time.parse_iso8601(timestamp)
      -- Should return a number (unix timestamp)
      assert.is.not_nil(result)
      assert.is_number(result)
    end)

    it('should handle timestamps with milliseconds', function()
      local timestamp = '2025-10-19T12:00:00.123Z'
      local result = time.parse_iso8601(timestamp)
      assert.is.not_nil(result)
      assert.is_number(result)
    end)

    it('should return nil for malformed timestamp without throwing', function()
      -- GitHub may return non-Z-suffix timestamps in unusual cases;
      -- a throw here would crash the history buffer rendering.
      local result = time.parse_iso8601('2025-10-19T12:00:00+09:00')
      assert.is_nil(result)
    end)

    it('should return nil for empty string without throwing', function()
      local result = time.parse_iso8601('')
      assert.is_nil(result)
    end)
  end)

  describe('format_relative resilience', function()
    it('should return a fallback string instead of throwing on malformed input', function()
      local ok, result = pcall(time.format_relative, 'not a timestamp')
      assert.is_true(ok, 'format_relative must not throw on malformed input')
      assert.is_string(result)
    end)

    it('should report "just now" for clock-skew future timestamps instead of negative units', function()
      -- timestamp 60 seconds in the future relative to current_time
      local current = os.time({ year = 2025, month = 11, day = 14, hour = 12, min = 0, sec = 0 })
      local future_ts = os.date('!%Y-%m-%dT%H:%M:%SZ', current + 60)

      local result = time.format_relative(future_ts, current)

      -- Must NOT contain a negative number or stale "-60s ago"; treat as immediate
      assert.is_false(
        result:find('-') ~= nil and result ~= '-',
        'future timestamps must not produce negative-duration output, got: ' .. result
      )
      assert.equals('just now', result)
    end)
  end)
end)
