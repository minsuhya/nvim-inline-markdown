---@class InlineMarkdown.Config
local M = {}

---@type InlineMarkdown.Config
M.defaults = {
  -- filetypes to attach to
  file_types = { "markdown" },
  -- automatically render when a markdown buffer is opened
  render_on_open = false,
  -- buffer-local keymap to toggle rendering (set to false to disable)
  keymap = "<leader>mp",
  -- debounce for re-rendering after text changes (ms)
  debounce_ms = 300,
  -- window options applied while rendering is enabled (restored on disable)
  win_options = {
    conceallevel = 2,
    concealcursor = "nc",
  },
  style = {
    headings = {
      -- one icon per level (h1..h6)
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      -- highlight the full line background
      background = true,
    },
    bullets = { "●", "○", "◆", "◇" }, -- cycled by indent level
    checkbox = {
      unchecked = "󰄱 ",
      checked = "󰱒 ",
    },
    code = {
      -- highlight code block background
      background = true,
      -- show language label on the opening fence
      language_label = true,
    },
    quote = { icon = "▍" },
    link = { icon = "󰌹 " },
    rule = { char = "─", width = 80 },
    table_borders = true,
    -- conceal **bold** / *italic* / `code` delimiters
    conceal_inline = true,
  },
  mermaid = {
    enabled = true,
    -- path to mermaid-cli executable
    mmdc_path = "mmdc",
    -- mermaid theme: "auto" follows vim.o.background (dark -> "dark", light -> "default")
    theme = "auto",
    -- rendered png background ("transparent" or css color)
    background = "transparent",
    -- puppeteer viewport width in px passed to mmdc
    width = 1200,
    -- device scale factor (2 = retina sharpness)
    scale = 2,
    -- max concurrent mmdc jobs
    max_jobs = 2,
    -- extra args appended to the mmdc command
    extra_args = {},
  },
}

---@type InlineMarkdown.Config
M.options = vim.deepcopy(M.defaults)

---@param opts table|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

---Resolved mermaid theme for the current colorscheme background.
---@return string
function M.mermaid_theme()
  local theme = M.options.mermaid.theme
  if theme ~= "auto" then return theme end
  return vim.o.background == "dark" and "dark" or "default"
end

return M
