local M = {}

M.ns = vim.api.nvim_create_namespace("inline-markdown")

---@class InlineMarkdown.BufState
---@field enabled boolean
---@field images table<string, any> image.nvim objects keyed by hash:row
---@field saved_win_opts table<integer, table<string, any>> per-window saved options
---@field timer uv.uv_timer_t|nil
---@field augroup integer|nil

---@type table<integer, InlineMarkdown.BufState>
local buffers = {}

---@param buf integer
---@return InlineMarkdown.BufState
function M.get(buf)
  if not buffers[buf] then
    buffers[buf] = {
      enabled = false,
      images = {},
      saved_win_opts = {},
      timer = nil,
      augroup = nil,
    }
  end
  return buffers[buf]
end

---@param buf integer
---@return boolean
function M.is_enabled(buf)
  local s = buffers[buf]
  return s ~= nil and s.enabled
end

---@param buf integer
function M.drop(buf)
  local s = buffers[buf]
  if s and s.timer then
    s.timer:stop()
    if not s.timer:is_closing() then s.timer:close() end
  end
  buffers[buf] = nil
end

return M
