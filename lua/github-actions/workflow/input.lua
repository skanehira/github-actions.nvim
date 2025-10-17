---@class InputCollector
local M = {}

---@class InputValue
---@field name string Input parameter name
---@field value string Input parameter value

---Validate a single input value
---@param input WorkflowDispatchInput Input definition
---@param value string|nil Input value
---@return boolean is_valid True if valid
---@return string|nil error_message Error message if invalid
function M.validate_input(input, value)
  if not value or value == '' then
    if input.required then
      return false, string.format('Input "%s" is required', input.name)
    end
    -- Optional empty input is valid (will be skipped)
    return true, nil
  end
  return true, nil
end

---@class CollectInputsHandlers
---@field on_success fun(input_values: InputValue[]) Called when all inputs are collected successfully
---@field on_error fun(error: string) Called when input collection fails

---Collect input values from user using vim.ui.input
---@param inputs WorkflowDispatchInput[] List of input definitions
---@param handlers CollectInputsHandlers Success and error handlers
function M.collect_inputs(inputs, handlers)
  if #inputs == 0 then
    handlers.on_success({})
    return
  end

  local input_values = {}
  local current_index = 1

  local function collect_next()
    if current_index > #inputs then
      -- All inputs collected successfully
      handlers.on_success(input_values)
      return
    end

    local input = inputs[current_index]
    local prompt = string.format('%s%s:', input.description or input.name, input.required and ' (required)' or '')

    vim.ui.input({
      prompt = prompt,
      default = input.default or '',
    }, function(value)
      vim.schedule(function()
        local is_valid, error_message = M.validate_input(input, value)

        if not is_valid then
          ---@cast error_message string
          handlers.on_error(error_message)
          return
        end

        -- Add value if not empty
        if value and value ~= '' then
          table.insert(input_values, { name = input.name, value = value })
        end

        -- Move to next input
        current_index = current_index + 1
        collect_next()
      end)
    end)
  end

  collect_next()
end

return M
