local state = require("inline-markdown.state")

local M = {}

---image.nvim module, or false when unavailable.
local image_nvim

local function backend()
  if image_nvim == nil then
    local ok, mod = pcall(require, "image")
    image_nvim = ok and mod or false
  end
  return image_nvim
end

---Whether images can actually be drawn (needs image.nvim and an attached UI).
---@return boolean
function M.available()
  return backend() ~= false and #vim.api.nvim_list_uis() > 0
end

---Show a rendered diagram below its code block.
---@param buf integer
---@param key string stable identity (hash .. ":" .. row)
---@param png string
---@param block InlineMarkdown.MermaidBlock
---@param seen table<string, boolean> keys shown during this render pass
function M.show(buf, key, png, block, seen)
  seen[key] = true
  if not M.available() then return end

  local st = state.get(buf)
  if st.images[key] then
    pcall(st.images[key].render, st.images[key])
    return
  end

  local win = vim.fn.win_findbuf(buf)[1]
  if not win then return end

  local ok, img = pcall(backend().from_file, png, {
    buffer = buf,
    window = win,
    x = 0,
    y = block.end_row + 1,
    with_virtual_padding = true,
    inline = true,
  })
  if ok and img then
    st.images[key] = img
    pcall(img.render, img)
  end
end

---Placeholder while mmdc is running.
---@param buf integer
---@param block InlineMarkdown.MermaidBlock
function M.pending(buf, block)
  vim.api.nvim_buf_set_extmark(buf, state.ns, block.end_row, 0, {
    virt_lines = { { { "  󰔟 rendering mermaid…", "InlineMarkdownPending" } } },
  })
end

---Error message below a broken diagram.
---@param buf integer
---@param block InlineMarkdown.MermaidBlock
---@param msg string
function M.error(buf, block, msg)
  local lines = {}
  for _, l in ipairs(vim.split(msg, "\n", { trimempty = true })) do
    lines[#lines + 1] = { { "  ✘ " .. l, "InlineMarkdownError" } }
    if #lines >= 3 then break end
  end
  if #lines == 0 then
    lines = { { { "  ✘ mermaid render failed", "InlineMarkdownError" } } }
  end
  vim.api.nvim_buf_set_extmark(buf, state.ns, block.end_row, 0, {
    virt_lines = lines,
  })
end

---Remove images whose block disappeared or changed.
---@param buf integer
---@param seen table<string, boolean>
function M.prune(buf, seen)
  local st = state.get(buf)
  for key, img in pairs(st.images) do
    if not seen[key] then
      pcall(img.clear, img)
      st.images[key] = nil
    end
  end
end

---Remove every image for a buffer.
---@param buf integer
function M.clear(buf)
  M.prune(buf, {})
end

return M
