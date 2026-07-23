local state = require("inline-markdown.state")

local M = {}

local block_query_src = [[
  (atx_heading) @heading
  (list_item) @list_item
  (fenced_code_block) @code
  (block_quote) @callout
  (block_quote_marker) @quote
  (thematic_break) @rule
  (pipe_table) @table
]]

local inline_query_src = [[
  (inline_link) @link
  (emphasis) @emphasis
  (strong_emphasis) @emphasis
  (code_span) @code_span
  (strikethrough) @strikethrough
  (uri_autolink) @autolink
]]

-- for parsers built without the GFM strikethrough/autolink extensions
local inline_query_fallback_src = [[
  (inline_link) @link
  (emphasis) @emphasis
  (strong_emphasis) @emphasis
  (code_span) @code_span
]]

local renderers = {
  heading = require("inline-markdown.render.heading"),
  list_item = require("inline-markdown.render.list"),
  code = require("inline-markdown.render.code"),
  callout = require("inline-markdown.render.callout"),
  quote = require("inline-markdown.render.quote"),
  rule = require("inline-markdown.render.rule"),
  table = require("inline-markdown.render.table"),
}

local inline = require("inline-markdown.render.inline")

local block_query, inline_query

local function queries()
  if not block_query then
    block_query = vim.treesitter.query.parse("markdown", block_query_src)
  end
  if not inline_query then
    local ok, q = pcall(vim.treesitter.query.parse, "markdown_inline", inline_query_src)
    if not ok then
      ok, q = pcall(vim.treesitter.query.parse, "markdown_inline", inline_query_fallback_src)
    end
    inline_query = ok and q or false
  end
  return block_query, inline_query
end

---Clear all decorations for a buffer.
---@param buf integer
function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
end

---Render all decorations (blocks + inlines + mermaid) for a buffer.
---@param buf integer
function M.render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then return end

  M.clear(buf)
  parser:parse(true)

  local bq, iq = queries()
  parser:for_each_tree(function(tree, ltree)
    local lang = ltree:lang()
    local root = tree:root()
    if lang == "markdown" then
      for id, node in bq:iter_captures(root, buf, 0, -1) do
        local name = bq.captures[id]
        local renderer = renderers[name]
        if renderer then
          pcall(renderer.render, buf, node)
        end
      end
    elseif lang == "markdown_inline" and iq then
      for id, node in iq:iter_captures(root, buf, 0, -1) do
        pcall(inline.render, buf, iq.captures[id], node)
      end
    end
  end)

  require("inline-markdown.mermaid").render(buf)
end

return M
