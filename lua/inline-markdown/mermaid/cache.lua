local config = require("inline-markdown.config")

local M = {}

---Render errors by hash — prevents endless retry of a broken diagram.
---@type table<string, string>
M.errors = {}

---@return string
function M.dir()
  return vim.fs.joinpath(vim.fn.stdpath("cache"), "inline-markdown")
end

---Content hash for a mermaid block, including settings that affect output.
---@param content string
---@return string
function M.hash(content)
  local m = config.options.mermaid
  local key = table.concat({
    content,
    config.mermaid_theme(),
    m.background,
    tostring(m.width),
    tostring(m.scale),
  }, "\0")
  return vim.fn.sha256(key):sub(1, 32)
end

---@param hash string
---@return string png path
function M.path(hash)
  return vim.fs.joinpath(M.dir(), hash .. ".png")
end

---@param hash string
---@return boolean
function M.exists(hash)
  return vim.uv.fs_stat(M.path(hash)) ~= nil
end

function M.ensure_dir()
  vim.fn.mkdir(M.dir(), "p")
end

function M.clear_errors()
  M.errors = {}
end

return M
