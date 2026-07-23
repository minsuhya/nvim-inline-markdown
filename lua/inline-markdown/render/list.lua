local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local M = {}

local BULLET_MARKERS = {
  list_marker_minus = true,
  list_marker_plus = true,
  list_marker_star = true,
}

---Nesting depth of a list item (0-based).
---@param node TSNode
---@return integer
local function depth(node)
  local d, cur = 0, node:parent()
  while cur do
    if cur:type() == "list" then d = d + 1 end
    cur = cur:parent()
  end
  return math.max(d - 1, 0)
end

---@param buf integer
---@param node TSNode list_item node
function M.render(buf, node)
  local style = config.options.style
  local marker, task
  for child in node:iter_children() do
    local t = child:type()
    if BULLET_MARKERS[t] then
      marker = child
    elseif t == "task_list_marker_checked" or t == "task_list_marker_unchecked" then
      task = child
    end
  end
  if not marker then return end

  local mrow, mcol, _, mecol = marker:range()

  if task then
    local done = task:type() == "task_list_marker_checked"
    local icon = done and style.checkbox.checked or style.checkbox.unchecked
    local hl = done and "InlineMarkdownCheckboxDone" or "InlineMarkdownCheckboxTodo"
    -- hide the list marker and the whole `[x]`, then insert the icon
    vim.api.nvim_buf_set_extmark(buf, state.ns, mrow, mcol, {
      end_col = mecol,
      conceal = "",
    })
    local trow, tcol, terow, tecol = task:range()
    vim.api.nvim_buf_set_extmark(buf, state.ns, trow, tcol, {
      end_row = terow,
      end_col = tecol,
      conceal = "",
    })
    vim.api.nvim_buf_set_extmark(buf, state.ns, trow, tcol, {
      virt_text = { { icon, hl } },
      virt_text_pos = "inline",
    })
    return
  end

  local bullets = style.bullets
  local bullet = bullets[(depth(node) % #bullets) + 1]
  vim.api.nvim_buf_set_extmark(buf, state.ns, mrow, mcol, {
    virt_text = { { bullet, "InlineMarkdownBullet" } },
    virt_text_pos = "overlay",
  })
end

return M
