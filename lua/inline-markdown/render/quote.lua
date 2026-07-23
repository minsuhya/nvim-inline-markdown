local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

---Positions of quote `>` chars covered by a marker/continuation node.
---(continuation lines represent their `> ` prefix as a block_continuation node)
---@param buf integer
---@param node TSNode block_quote_marker or block_continuation node
---@return { [1]: integer, [2]: integer }[] (row, col) pairs
function M.positions(buf, node)
  local row, col = node:range()
  if node:type() == "block_quote_marker" then
    return { { row, col } }
  end
  local out = {}
  local text = vim.treesitter.get_node_text(node, buf)
  local first_line = text:match("^[^\n]*")
  local i = first_line:find(">", 1, true)
  while i do
    out[#out + 1] = { row, col + i - 1 }
    i = first_line:find(">", i + 1, true)
  end
  return out
end

---@param buf integer
---@param node TSNode block_quote_marker or block_continuation node
function M.render(buf, node)
  for _, pos in ipairs(M.positions(buf, node)) do
    vim.api.nvim_buf_set_extmark(buf, state.ns, pos[1], pos[2], {
      virt_text = { { config.options.style.quote.icon, "InlineMarkdownQuote" } },
      virt_text_pos = "overlay",
    })
  end
end

return M
