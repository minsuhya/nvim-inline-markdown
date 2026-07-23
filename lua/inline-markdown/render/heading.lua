local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

---@param buf integer
---@param node TSNode atx_heading node
function M.render(buf, node)
  local marker = node:child(0)
  if not marker then return end
  local level = tonumber(marker:type():match("atx_h(%d)_marker"))
  if not level then return end

  local style = config.options.style.headings
  local icon = style.icons[level] or style.icons[#style.icons]
  local hl = "InlineMarkdownH" .. level
  local row, col = marker:range()

  -- overlay the icon on top of the `#` marker (including its trailing space)
  vim.api.nvim_buf_set_extmark(buf, state.ns, row, col, {
    virt_text = { { icon, hl } },
    virt_text_pos = "overlay",
    conceal = "",
  })

  if style.background then
    vim.api.nvim_buf_set_extmark(buf, state.ns, row, 0, {
      line_hl_group = hl .. "Bg",
      hl_eol = true,
    })
  end

  -- highlight the heading text itself
  local srow, scol, erow, ecol = node:range()
  vim.api.nvim_buf_set_extmark(buf, state.ns, srow, scol, {
    end_row = erow,
    end_col = ecol,
    hl_group = hl,
  })
end

return M
