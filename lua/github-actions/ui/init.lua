---@class Ui
---@field version UiVersion Version display module
---@field highlights Highlights Highlight groups module
local M = {}

M.version = require('github-actions.ui.version')
M.highlights = require('github-actions.ui.highlights')

return M
