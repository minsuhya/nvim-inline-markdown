local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

---Language of a fenced code block, if declared.
---@param buf integer
---@param node TSNode fenced_code_block
---@return string|nil
function M.language(buf, node)
  for child in node:iter_children() do
    if child:type() == "info_string" then
      for sub in child:iter_children() do
        if sub:type() == "language" then
          return vim.treesitter.get_node_text(sub, buf)
        end
      end
    end
  end
  return nil
end

---@param buf integer
---@param node TSNode fenced_code_block node
function M.render(buf, node)
  local style = config.options.style.code
  local srow, _, erow, ecol = node:range()
  -- when the block ends at col 0, the last line is exclusive
  local last = ecol == 0 and erow - 1 or erow

  if style.background then
    for row = srow, last do
      vim.api.nvim_buf_set_extmark(buf, state.ns, row, 0, {
        line_hl_group = "InlineMarkdownCode",
        hl_eol = true,
      })
    end
  end

  local lang = M.language(buf, node)
  if style.language_label and lang then
    local line = vim.api.nvim_buf_get_lines(buf, srow, srow + 1, false)[1] or ""
    -- cover the entire opening fence (```lang) with a label
    local label = " " .. lang
    if vim.fn.strdisplaywidth(label) < vim.fn.strdisplaywidth(line) then
      label = label .. string.rep(" ", vim.fn.strdisplaywidth(line) - vim.fn.strdisplaywidth(label))
    end
    vim.api.nvim_buf_set_extmark(buf, state.ns, srow, 0, {
      virt_text = { { label, "InlineMarkdownCodeLang" } },
      virt_text_pos = "overlay",
    })
  end

  -- hide the closing fence backticks
  local close_line = vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1] or ""
  if close_line:match("^%s*[`~]+%s*$") then
    vim.api.nvim_buf_set_extmark(buf, state.ns, last, 0, {
      virt_text = { { string.rep(" ", #close_line), "InlineMarkdownCode" } },
      virt_text_pos = "overlay",
    })
  end
end

return M
