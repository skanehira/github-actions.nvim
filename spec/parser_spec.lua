-- Test for workflow parser

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local helpers = require('spec.helpers.buffer_spec')

describe('workflow parser', function()
  local parser

  before_each(function()
    parser = require('github-actions.parser.workflow')
  end)

  describe('parse_buffer', function()
    it('should extract actions from workflow file', function()
      local test_cases = {
        {
          name = 'basic workflow with multiple actions',
          content = [[
name: Test Workflow

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - uses: docker/setup-buildx-action@v2
]],
          expected = {
            { owner = 'actions', repo = 'checkout', version = 'v3', line = 10 },
            { owner = 'actions', repo = 'setup-node', version = 'v3', line = 11 },
            { owner = 'docker', repo = 'setup-buildx-action', version = 'v2', line = 14 },
          },
        },
        {
          name = 'actions with different version formats',
          content = [[
jobs:
  test:
    steps:
      - uses: actions/checkout@v3.5.0
      - uses: actions/setup-go@v4.1.0
      - uses: actions/cache@main
]],
          expected = {
            { owner = 'actions', repo = 'checkout', version = 'v3.5.0', line = 3 },
            { owner = 'actions', repo = 'setup-go', version = 'v4.1.0', line = 4 },
            { owner = 'actions', repo = 'cache', version = 'main', line = 5 },
          },
        },
        {
          name = 'actions with trailing comments',
          content = [[
jobs:
  test:
    steps:
      - uses: actions/checkout@v3  # latest stable
      - uses: actions/setup-node@v4  # Node.js setup
]],
          expected = {
            { owner = 'actions', repo = 'checkout', version = 'v3', line = 3 },
            { owner = 'actions', repo = 'setup-node', version = 'v4', line = 4 },
          },
        },
        {
          name = 'actions with hash and version comment',
          content = [[
jobs:
  test:
    steps:
      - uses: taiki-e/install-action@e30c5b8cfc4910a9f163907c8149ac1e54f1ab11 # v2.62.25
      - uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29 # v4.1.6
]],
          expected = {
            {
              owner = 'taiki-e',
              repo = 'install-action',
              hash = 'e30c5b8cfc4910a9f163907c8149ac1e54f1ab11',
              version = 'v2.62.25',
              line = 3,
            },
            {
              owner = 'actions',
              repo = 'checkout',
              hash = 'a5ac7e51b41094c92402da3b24376905380afc29',
              version = 'v4.1.6',
              line = 4,
            },
          },
        },
        {
          name = 'actions with hash only',
          content = [[
jobs:
  test:
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
]],
          expected = {
            {
              owner = 'actions',
              repo = 'checkout',
              hash = '8e5e7e5ab8b370d6c329ec480221332ada57f0ab',
              line = 3,
            },
          },
        },
      }

      for _, tc in ipairs(test_cases) do
        local bufnr = helpers.create_yaml_buffer(tc.content)
        local actions = parser.parse_buffer(bufnr)

        assert.equals(#tc.expected, #actions, tc.name .. ': action count mismatch')

        for i, expected in ipairs(tc.expected) do
          assert.equals(expected.owner, actions[i].owner, tc.name .. ': owner mismatch at index ' .. i)
          assert.equals(expected.repo, actions[i].repo, tc.name .. ': repo mismatch at index ' .. i)
          assert.equals(expected.line, actions[i].line, tc.name .. ': line mismatch at index ' .. i)

          if expected.version then
            assert.equals(expected.version, actions[i].version, tc.name .. ': version mismatch at index ' .. i)
          end

          if expected.hash then
            assert.equals(expected.hash, actions[i].hash, tc.name .. ': hash mismatch at index ' .. i)
          end
        end

        helpers.delete_buffer(bufnr)
      end
    end)

    it('should return empty array for buffer without actions', function()
      local content = [[
name: Test Workflow

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Echo
        run: echo "hello"
]]
      local bufnr = helpers.create_yaml_buffer(content)

      local actions = parser.parse_buffer(bufnr)

      assert.equals(0, #actions)

      helpers.delete_buffer(bufnr)
    end)

    it('should handle invalid buffer', function()
      local actions = parser.parse_buffer(999999)

      assert.equals(0, #actions)
    end)
  end)
end)
