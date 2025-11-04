dofile('spec/minimal_init.lua')

describe('history.log_parser', function()
  local log_parser = require('github-actions.history.log_parser')

  describe('parse', function()
    it('should parse gh CLI log format and extract timestamp and content', function()
      local raw_log = [[lint	UNKNOWN STEP	2025-10-17T11:23:49.1573737Z Current runner version: '2.328.0'
lint	UNKNOWN STEP	2025-10-17T11:23:49.1597853Z ##[group]Runner Image Provisioner
lint	Set up job	2025-10-17T11:23:49.1598714Z Hosted Compute Agent]]

      local result = log_parser.parse(raw_log)

      -- Should extract time and content, removing job and step columns
      assert.matches('%[11:23:49%] Current runner version', result)
      assert.matches('%[11:23:49%] ##%[group%]Runner Image Provisioner', result)
      assert.matches('%[11:23:49%] Hosted Compute Agent', result)

      -- Should NOT contain job name or step name columns
      assert.not_matches('lint\t', result)
      assert.not_matches('UNKNOWN STEP', result)
      assert.not_matches('Set up job', result)
    end)

    it('should handle empty logs', function()
      local result = log_parser.parse('')
      assert.equals('', result)
    end)

    it('should handle nil logs', function()
      local result = log_parser.parse(nil)
      assert.equals('', result)
    end)

    it('should format multiple log entries with different timestamps', function()
      local raw_log = [[test	Run tests	2025-10-18T04:09:37.1234567Z ##[group]Run npm test
test	Run tests	2025-10-18T04:09:38.4567890Z > test
test	Run tests	2025-10-18T04:09:40.8901234Z PASS spec/example_spec.js]]

      local result = log_parser.parse(raw_log)

      assert.matches('%[04:09:37%] ##%[group%]Run npm test', result)
      assert.matches('%[04:09:38%] > test', result)
      assert.matches('%[04:09:40%] PASS spec/example_spec.js', result)
    end)

    it('should handle lines without proper tab format gracefully', function()
      local raw_log = [[Some malformed line
lint	UNKNOWN STEP	2025-10-17T11:23:49.1573737Z Valid log line]]

      local result = log_parser.parse(raw_log)

      -- Malformed line should be included as-is
      assert.matches('Some malformed line', result)
      -- Valid line should be formatted
      assert.matches('%[11:23:49%] Valid log line', result)
    end)

    it('should strip ANSI escape sequences by default', function()
      -- Use actual ANSI escape sequences with \27 (ESC character in octal)
      local esc = string.char(27)
      local raw_log = 'test\tRun\t2025-10-18T04:09:37.1234567Z '
        .. esc
        .. '[32m==>'
        .. esc
        .. '[0m '
        .. esc
        .. '[1mFetching '
        .. esc
        .. '[32mneovim'
        .. esc
        .. '[39m'
        .. esc
        .. '[0m'

      local result = log_parser.parse(raw_log)

      -- ANSI codes should be stripped (escaped bracket patterns)
      assert.not_matches(esc .. '%[32m', result)
      assert.not_matches(esc .. '%[0m', result)
      assert.not_matches(esc .. '%[1m', result)
      assert.not_matches(esc .. '%[39m', result)

      -- Content should remain
      assert.matches('%[04:09:37%]', result)
      assert.matches('==> Fetching neovim', result)
    end)

    it('should keep ANSI escape sequences when strip_ansi is false', function()
      -- Use actual ANSI escape sequences with \27 (ESC character in octal)
      local esc = string.char(27)
      local raw_log = 'test\tRun\t2025-10-18T04:09:37.1234567Z '
        .. esc
        .. '[32m==>'
        .. esc
        .. '[0m '
        .. esc
        .. '[1mFetching '
        .. esc
        .. '[32mneovim'
        .. esc
        .. '[39m'
        .. esc
        .. '[0m'

      local result = log_parser.parse(raw_log, { strip_ansi = false })

      -- ANSI codes should be preserved
      assert.matches(esc .. '%[32m', result)
      assert.matches(esc .. '%[0m', result)
      assert.matches(esc .. '%[1m', result)
      assert.matches(esc .. '%[39m', result)

      -- Content should also be there
      assert.matches('%[04:09:37%]', result)
      assert.matches('Fetching', result)
      assert.matches('neovim', result)
    end)

    it('should remove BOM (Byte Order Mark) characters from logs', function()
      -- BOM character: U+FEFF (UTF-8: EF BB BF)
      local bom = '\239\187\191' -- UTF-8 encoded BOM
      local raw_log = 'test\tRun\t2025-10-18T04:09:37.1234567Z '
        .. bom
        .. 'Starting job'
        .. bom
        .. ' with '
        .. bom
        .. 'BOM characters'

      local result = log_parser.parse(raw_log)

      -- BOM should be stripped
      assert.not_matches('\239\187\191', result)

      -- Content should remain
      assert.matches('%[04:09:37%]', result)
      assert.matches('Starting job with BOM characters', result)
    end)

    it('should remove BOM from multiple log lines', function()
      local bom = '\239\187\191'
      local raw_log = bom
        .. 'test\tRun\t2025-10-18T04:09:37.1234567Z First line'
        .. bom
        .. '\n'
        .. 'test\tRun\t2025-10-18T04:09:38.1234567Z '
        .. bom
        .. 'Second line'
        .. bom

      local result = log_parser.parse(raw_log)

      -- BOM should be stripped from all lines
      assert.not_matches('\239\187\191', result)

      -- Content should remain
      assert.matches('%[04:09:37%] First line', result)
      assert.matches('%[04:09:38%] Second line', result)
    end)
  end)
end)
