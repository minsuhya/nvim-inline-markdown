local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

---@param buf integer
---@param node TSNode thematic_break node
function M.render(buf, node)
  local style = config.options.style.rule
  local row = node:range()
  vim.api.nvim_buf_set_extmark(buf, state.ns, row, 0, {
    virt_text = { { string.rep(style.char, style.width), "InlineMarkdownRule" } },
    virt_text_pos = "overlay",
  })
end

return M
