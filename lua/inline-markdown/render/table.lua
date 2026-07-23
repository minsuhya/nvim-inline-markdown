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

---Build a display-width-aware outer border (`┌─┬─┐` / `└─┴─┘`) from a row line.
---@param line string
---@param left string
---@param mid string
---@param right string
---@return string|nil
local function outer_border(line, left, mid, right)
  local chars = vim.fn.split(line, "\\zs")
  local pipes = {}
  for idx, ch in ipairs(chars) do
    if ch == "|" then pipes[#pipes + 1] = idx end
  end
  if #pipes < 2 then return nil end
  local parts = {}
  for idx, ch in ipairs(chars) do
    if ch == "|" then
      parts[#parts + 1] = (idx == pipes[1] and left) or (idx == pipes[#pipes] and right) or mid
    elseif idx < pipes[1] then
      parts[#parts + 1] = string.rep(" ", vim.fn.strdisplaywidth(ch))
    elseif idx < pipes[#pipes] then
      parts[#parts + 1] = string.rep("─", vim.fn.strdisplaywidth(ch))
    end
  end
  return table.concat(parts)
end

---@param buf integer
---@param node TSNode pipe_table node
function M.render(buf, node)
  if not config.options.style.table_borders then return end
  local header_row, last_row
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
      header_row = row
    elseif t == "pipe_table_row" then
      style_pipes(buf, row)
      last_row = row
    end
  end

  -- github preset: closed outer borders above the header and below the last row
  if config.options.style.preset ~= "github" then return end
  if header_row then
    local line = vim.api.nvim_buf_get_lines(buf, header_row, header_row + 1, false)[1] or ""
    local top = outer_border(line, "┌", "┬", "┐")
    if top then
      vim.api.nvim_buf_set_extmark(buf, state.ns, header_row, 0, {
        virt_lines = { { { top, "InlineMarkdownTableBorder" } } },
        virt_lines_above = true,
      })
    end
  end
  if last_row then
    local line = vim.api.nvim_buf_get_lines(buf, last_row, last_row + 1, false)[1] or ""
    local bottom = outer_border(line, "└", "┴", "┘")
    if bottom then
      vim.api.nvim_buf_set_extmark(buf, state.ns, last_row, 0, {
        virt_lines = { { { bottom, "InlineMarkdownTableBorder" } } },
      })
    end
  end
end

return M
