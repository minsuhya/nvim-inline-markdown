local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

local function conceal_range(buf, srow, scol, erow, ecol)
  if srow == erow and scol >= ecol then return end
  vim.api.nvim_buf_set_extmark(buf, state.ns, srow, scol, {
    end_row = erow,
    end_col = ecol,
    conceal = "",
  })
end

---@param buf integer
---@param node TSNode inline_link node
local function render_link(buf, node)
  local text
  for child in node:iter_children() do
    if child:type() == "link_text" then
      text = child
      break
    end
  end
  if not text then return end

  local nsrow, nscol, nerow, necol = node:range()
  local tsrow, tscol, terow, tecol = text:range()

  -- conceal `[` and `](url)`
  conceal_range(buf, nsrow, nscol, tsrow, tscol)
  conceal_range(buf, terow, tecol, nerow, necol)

  local icon = config.options.style.link.icon
  if icon and icon ~= "" then
    vim.api.nvim_buf_set_extmark(buf, state.ns, tsrow, tscol, {
      virt_text = { { icon, "InlineMarkdownLink" } },
      virt_text_pos = "inline",
    })
  end
  vim.api.nvim_buf_set_extmark(buf, state.ns, tsrow, tscol, {
    end_row = terow,
    end_col = tecol,
    hl_group = "InlineMarkdownLink",
  })
end

---Conceal the delimiters of emphasis / strong_emphasis / code_span.
---@param buf integer
---@param node TSNode
local function conceal_delimiters(buf, node)
  local found = false
  for child in node:iter_children() do
    local t = child:type()
    if t == "emphasis_delimiter" or t == "code_span_delimiter" then
      found = true
      conceal_range(buf, child:range())
    end
  end
  if not found then
    -- fallback: conceal one char on each side
    local srow, scol, erow, ecol = node:range()
    conceal_range(buf, srow, scol, srow, scol + 1)
    conceal_range(buf, erow, ecol - 1, erow, ecol)
  end
end

---@param buf integer
---@param capture string
---@param node TSNode
function M.render(buf, capture, node)
  if capture == "link" then
    render_link(buf, node)
    return
  end
  if not config.options.style.conceal_inline then return end
  if capture == "emphasis" or capture == "code_span" then
    conceal_delimiters(buf, node)
  end
end

return M
