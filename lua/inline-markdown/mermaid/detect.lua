local code = require("inline-markdown.render.code")

local M = {}

---@class InlineMarkdown.MermaidBlock
---@field content string mermaid source
---@field start_row integer 0-indexed row of the opening fence
---@field end_row integer 0-indexed row of the closing fence

local query_src = "(fenced_code_block) @block"
local query

---Find all ```mermaid blocks in a buffer.
---@param buf integer
---@return InlineMarkdown.MermaidBlock[]
function M.blocks(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then return {} end
  query = query or vim.treesitter.query.parse("markdown", query_src)

  local blocks = {}
  parser:parse(true)
  for _, tree in ipairs(parser:trees()) do
    for _, node in query:iter_captures(tree:root(), buf, 0, -1) do
      if code.language(buf, node) == "mermaid" then
        local content
        for child in node:iter_children() do
          if child:type() == "code_fence_content" then
            content = vim.treesitter.get_node_text(child, buf)
            break
          end
        end
        if content and content:match("%S") then
          local srow, _, erow, ecol = node:range()
          blocks[#blocks + 1] = {
            content = content,
            start_row = srow,
            end_row = ecol == 0 and erow - 1 or erow,
          }
        end
      end
    end
  end
  return blocks
end

return M
