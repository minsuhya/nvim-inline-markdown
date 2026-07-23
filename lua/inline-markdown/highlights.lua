local M = {}

---Get a highlight group's resolved attributes.
---@param name string
---@return vim.api.keyset.get_hl_info
local function get_hl(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

---Blend two 24-bit colors. `alpha` is the weight of `fg` (0..1).
---@param fg integer|nil
---@param bg integer|nil
---@param alpha number
---@return integer|nil
local function blend(fg, bg, alpha)
  if not fg or not bg then return fg or bg end
  local function channel(shift)
    local f = bit.band(bit.rshift(fg, shift), 0xff)
    local b = bit.band(bit.rshift(bg, shift), 0xff)
    return math.floor(f * alpha + b * (1 - alpha) + 0.5)
  end
  return bit.bor(bit.lshift(channel(16), 16), bit.lshift(channel(8), 8), channel(0))
end

function M.setup()
  local normal = get_hl("Normal")
  local normal_bg = normal.bg or (vim.o.background == "dark" and 0x000000 or 0xffffff)

  for level = 1, 6 do
    local src = get_hl("@markup.heading." .. level .. ".markdown")
    if not src.fg then src = get_hl("Title") end
    vim.api.nvim_set_hl(0, "InlineMarkdownH" .. level, {
      default = true,
      fg = src.fg,
      bold = true,
    })
    -- subtle background derived from the heading color
    vim.api.nvim_set_hl(0, "InlineMarkdownH" .. level .. "Bg", {
      default = true,
      bg = blend(src.fg, normal_bg, 0.12),
    })
  end

  local comment = get_hl("Comment")
  vim.api.nvim_set_hl(0, "InlineMarkdownCode", {
    default = true,
    bg = blend(comment.fg, normal_bg, 0.08),
  })
  vim.api.nvim_set_hl(0, "InlineMarkdownCodeLang", { default = true, link = "Comment" })
  vim.api.nvim_set_hl(0, "InlineMarkdownBullet", { default = true, link = "Special" })
  vim.api.nvim_set_hl(0, "InlineMarkdownCheckboxDone", { default = true, link = "DiagnosticOk" })
  vim.api.nvim_set_hl(0, "InlineMarkdownCheckboxTodo", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "InlineMarkdownQuote", { default = true, link = "Comment" })
  vim.api.nvim_set_hl(0, "InlineMarkdownLink", { default = true, link = "@markup.link.label.markdown_inline" })
  vim.api.nvim_set_hl(0, "InlineMarkdownRule", { default = true, link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "InlineMarkdownTableBorder", { default = true, link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "InlineMarkdownTableHead", { default = true, bold = true })
  vim.api.nvim_set_hl(0, "InlineMarkdownPending", { default = true, link = "DiagnosticHint" })
  vim.api.nvim_set_hl(0, "InlineMarkdownError", { default = true, link = "DiagnosticError" })
end

return M
