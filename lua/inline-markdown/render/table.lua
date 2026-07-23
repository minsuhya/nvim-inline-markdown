local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

---Overlay every `|` in a row line with a box-drawing bar.
---@param buf integer
---@param row integer
local function style_pipes(buf, row)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local col = line:find("|", 1, true)
  while col do
    vim.api.nvim_buf_set_extmark(buf, state.ns, row, col - 1, {
      virt_text = { { "│", "InlineMarkdownTableBorder" } },
      virt_text_pos = "overlay",
    })
    col = line:find("|", col + 1, true)
  end
end

---Replace the `|---|---|` delimiter row with `├───┼───┤`.
---@param buf integer
---@param row integer
local function style_delimiter(buf, row)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local first = line:find("|", 1, true)
  local last = line:reverse():find("|", 1, true)
  last = last and (#line - last + 1) or nil
  local out = {}
  for i = 1, #line do
    local ch = line:sub(i, i)
    if ch == "|" then
      out[i] = (i == first and "├") or (i == last and "┤") or "┼"
    elseif ch:match("%s") and i < (first or 1) then
      out[i] = " " -- keep indentation
    else
      out[i] = "─"
    end
  end
  vim.api.nvim_buf_set_extmark(buf, state.ns, row, 0, {
    virt_text = { { table.concat(out), "InlineMarkdownTableBorder" } },
    virt_text_pos = "overlay",
  })
end

---@param buf integer
---@param node TSNode pipe_table node
function M.render(buf, node)
  if not config.options.style.table_borders then return end
  for child in node:iter_children() do
    local t = child:type()
    local row = child:range()
    if t == "pipe_table_delimiter_row" then
      style_delimiter(buf, row)
    elseif t == "pipe_table_header" then
      local srow, scol, erow, ecol = child:range()
      vim.api.nvim_buf_set_extmark(buf, state.ns, srow, scol, {
        end_row = erow,
        end_col = ecol,
        hl_group = "InlineMarkdownTableHead",
      })
      style_pipes(buf, row)
    elseif t == "pipe_table_row" then
      style_pipes(buf, row)
    end
  end
end

return M
