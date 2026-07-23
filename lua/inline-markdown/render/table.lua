local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

---@class InlineMarkdown.TableRow
---@field lnum integer 0-indexed line number
---@field kind string pipe_table_header | pipe_table_delimiter_row | pipe_table_row
---@field line string raw line text
---@field pipes integer[] 1-based byte positions of every `|`

---@param buf integer
---@param node TSNode pipe_table node
---@return InlineMarkdown.TableRow[]
local function collect_rows(buf, node)
  local rows = {}
  for child in node:iter_children() do
    local t = child:type()
    if t == "pipe_table_header" or t == "pipe_table_delimiter_row" or t == "pipe_table_row" then
      local lnum = child:range()
      local line = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1] or ""
      local pipes = {}
      local col = line:find("|", 1, true)
      while col do
        pipes[#pipes + 1] = col
        col = line:find("|", col + 1, true)
      end
      if #pipes >= 2 then
        rows[#rows + 1] = { lnum = lnum, kind = t, line = line, pipes = pipes }
      end
    end
  end
  return rows
end

---Display width of cell i (text between pipe i and i+1) of a row.
---@param row InlineMarkdown.TableRow
---@param i integer
---@return integer
local function cell_width(row, i)
  return vim.fn.strdisplaywidth(row.line:sub(row.pipes[i] + 1, row.pipes[i + 1] - 1))
end

---Target display width per column: max cell width across header and data rows.
---@param rows InlineMarkdown.TableRow[]
---@return integer[] widths, integer ncols
local function column_widths(rows)
  local widths = {}
  for _, row in ipairs(rows) do
    if row.kind ~= "pipe_table_delimiter_row" then
      for i = 1, #row.pipes - 1 do
        widths[i] = math.max(widths[i] or 3, cell_width(row, i))
      end
    end
  end
  return widths, #widths
end

---Border line like `├───┼───┤` from target column widths.
---@param widths integer[]
---@param indent string
---@param left string
---@param mid string
---@param right string
---@return string
local function border(widths, indent, left, mid, right)
  local parts = { indent, left }
  for i, w in ipairs(widths) do
    parts[#parts + 1] = string.rep("─", w)
    parts[#parts + 1] = (i == #widths) and right or mid
  end
  return table.concat(parts)
end

---@param buf integer
---@param node TSNode pipe_table node
function M.render(buf, node)
  if not config.options.style.table_borders then return end
  local rows = collect_rows(buf, node)
  if #rows == 0 then return end
  local widths = column_widths(rows)
  if #widths == 0 then return end

  local header, last_data
  for _, row in ipairs(rows) do
    if row.kind == "pipe_table_delimiter_row" then
      -- rebuild the delimiter row at target widths
      local indent = row.line:sub(1, row.pipes[1] - 1):gsub("%S", " ")
      vim.api.nvim_buf_set_extmark(buf, state.ns, row.lnum, 0, {
        virt_text = { { border(widths, indent, "├", "┼", "┤"), "InlineMarkdownTableBorder" } },
        virt_text_pos = "overlay",
      })
    else
      if row.kind == "pipe_table_header" then
        header = row
        vim.api.nvim_buf_set_extmark(buf, state.ns, row.lnum, row.pipes[1] - 1, {
          end_col = row.pipes[#row.pipes],
          hl_group = "InlineMarkdownTableHead",
        })
      else
        last_data = row
      end
      -- restyle pipes and pad narrow cells so columns align across rows
      for i, col in ipairs(row.pipes) do
        vim.api.nvim_buf_set_extmark(buf, state.ns, row.lnum, col - 1, {
          virt_text = { { "│", "InlineMarkdownTableBorder" } },
          virt_text_pos = "overlay",
        })
        if i < #row.pipes then
          local pad = (widths[i] or 3) - cell_width(row, i)
          if pad > 0 then
            vim.api.nvim_buf_set_extmark(buf, state.ns, row.lnum, row.pipes[i + 1] - 1, {
              virt_text = { { string.rep(" ", pad), "Normal" } },
              virt_text_pos = "inline",
            })
          end
        end
      end
    end
  end

  -- github preset: closed outer borders above the header and below the last row
  if config.options.style.preset ~= "github" then return end
  if header then
    local indent = header.line:sub(1, header.pipes[1] - 1):gsub("%S", " ")
    vim.api.nvim_buf_set_extmark(buf, state.ns, header.lnum, 0, {
      virt_lines = { { { border(widths, indent, "┌", "┬", "┐"), "InlineMarkdownTableBorder" } } },
      virt_lines_above = true,
    })
    local bottom_anchor = last_data or header
    vim.api.nvim_buf_set_extmark(buf, state.ns, bottom_anchor.lnum, 0, {
      virt_lines = { { { border(widths, indent, "└", "┴", "┘"), "InlineMarkdownTableBorder" } } },
    })
  end
end

return M
