---@class Fixture
local M = {}

---Load a fixture file from spec/fixtures/
---@param name string The fixture name without extension
---@param ext? string The file extension (default: 'json')
---@return string content The fixture file content
function M.load(name, ext)
  ext = ext or 'json'
  local path = string.format('spec/fixtures/%s.%s', name, ext)
  local file = io.open(path, 'r')
  if not file then
    error('Fixture not found: ' .. path)
  end
  local content = file:read('*all')
  file:close()
  return content
end

return M
