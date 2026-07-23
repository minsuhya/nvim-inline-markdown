local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

---@param buf integer
---@param node TSNode block_quote_marker node
function M.render(buf, node)
  local row, col = node:range()
  vim.api.nvim_buf_set_extmark(buf, state.ns, row, col, {
    virt_text = { { config.options.style.quote.icon, "InlineMarkdownQuote" } },
    virt_text_pos = "overlay",
  })
end

return M
