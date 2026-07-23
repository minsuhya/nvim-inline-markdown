local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

local marker_query

---@param buf integer
---@param node TSNode block_quote node
function M.render(buf, node)
  local srow = node:range()
  local line = vim.api.nvim_buf_get_lines(buf, srow, srow + 1, false)[1] or ""
  local scol, ecol, kind = line:find("%[!(%a+)%]")
  if not kind then return end
  local spec = config.options.style.callout[kind:lower()]
  if not spec then return end

  -- replace `[!NOTE]` with a colored icon badge
  vim.api.nvim_buf_set_extmark(buf, state.ns, srow, scol - 1, {
    end_col = ecol,
    conceal = "",
  })
  vim.api.nvim_buf_set_extmark(buf, state.ns, srow, scol - 1, {
    virt_text = { { spec.icon .. spec.label, spec.hl } },
    virt_text_pos = "inline",
  })

  -- recolor every quote bar of this block (continuation lines included)
  marker_query = marker_query
    or vim.treesitter.query.parse("markdown", "[(block_quote_marker) (block_continuation)] @m")
  local quote = require("inline-markdown.render.quote")
  for _, marker in marker_query:iter_captures(node, buf) do
    for _, pos in ipairs(quote.positions(buf, marker)) do
      vim.api.nvim_buf_set_extmark(buf, state.ns, pos[1], pos[2], {
        virt_text = { { config.options.style.quote.icon, spec.hl } },
        virt_text_pos = "overlay",
        priority = 4500, -- above the plain quote renderer's overlay
      })
    end
  end
end

return M
