# nvim-inline-markdown

Clean, toggleable inline markdown rendering for Neovim — with **mermaid diagrams
rendered as real images** inside your buffer.

- Headings with icons and subtle backgrounds, styled bullets and checkboxes,
  code block backgrounds with language labels, box-drawing table borders,
  quote bars, concealed `**bold**` / `*italic*` / `` `code` `` / `~~strike~~` /
  link / `<autolink>` syntax
- GFM alerts (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`)
  rendered as colored icon badges with matching quote bars
- Two style presets: `default` (icons + heading backgrounds) and `github`
  (underlined h1/h2, thickness-graded `█ ▊ ▌ ▎` accent bars, closed table
  borders with header shading — closest to GitHub's web rendering)
- Heading depth is doubly encoded: the accent bar thins out level by level, and
  levels a colorscheme leaves identical (usually h4..h6) are progressively faded
  toward the background so they recede instead of all reading as the same level
- ` ```mermaid ` blocks are rendered to PNG via
  [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) (async, content-hash
  cached) and displayed inline below the block via
  [image.nvim](https://github.com/3rd/image.nvim)
- Toggle-centric UX: `:InlineMarkdown toggle` (default `<leader>mp`) switches
  between rendered view and plain text; while enabled, edits re-render
  automatically (debounced), and only changed diagrams are re-generated
- Broken diagrams show the mmdc error inline instead of retrying forever

## Requirements

- Neovim ≥ 0.10 with `markdown` / `markdown_inline` treesitter parsers
- [mermaid-cli](https://github.com/mermaid-js/mermaid-cli): `npm i -g @mermaid-js/mermaid-cli`
- [image.nvim](https://github.com/3rd/image.nvim) + ImageMagick (`brew install imagemagick`)
- A terminal with image support (kitty, ghostty, WezTerm, …).
  - WezTerm: `enable_kitty_graphics = true`
  - tmux: `set -gq allow-passthrough on`

Everything degrades gracefully: without mmdc or image.nvim you still get full
text styling. Run `:checkhealth inline-markdown` to diagnose your setup.

## Installation

### lazy.nvim / AstroNvim

```lua
{
  "minsuhya/nvim-inline-markdown",
  ft = "markdown",
  dependencies = {
    {
      "3rd/image.nvim",
      opts = {
        processor = "magick_cli",
        integrations = { markdown = { enabled = false } },
        max_width_window_percentage = 80,
      },
    },
  },
  opts = {},
}
```

## Usage

| Command | Action |
| --- | --- |
| `:InlineMarkdown` / `:InlineMarkdown toggle` | Toggle rendering for the current buffer |
| `:InlineMarkdown enable` / `disable` | Explicit on / off |
| `:InlineMarkdown refresh` | Force re-render (also retries failed diagrams) |

Default keymap: `<leader>mp` in markdown buffers.

## Configuration (defaults)

```lua
require("inline-markdown").setup({
  file_types = { "markdown" },
  render_on_open = false,      -- auto-enable when opening markdown files
  keymap = "<leader>mp",       -- false to disable
  debounce_ms = 300,
  win_options = { conceallevel = 2, concealcursor = "nc" },
  style = {
    preset = "default",        -- "default" | "github"
    headings = {
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      background = true,
      -- "github" preset accent bar. A list = one glyph per level (h1..h6), so
      -- thickness marks depth and all heading text lines up; a string like
      -- "▎" is repeated per depth instead (h2 "▎", h3 "▎▎", …).
      bar = { "█", "▊", "▌", "▎", "▏", "╎" },
    },
    bullets = { "●", "○", "◆", "◇" },
    checkbox = { unchecked = "󰄱 ", checked = "󰱒 " },
    code = { background = true, language_label = true },
    quote = { icon = "▍" },
    link = { icon = "󰌹 " },
    rule = { char = "─", width = 80 },
    table_borders = true,
    conceal_inline = true,
  },
  mermaid = {
    enabled = true,
    mmdc_path = "mmdc",
    theme = "auto",            -- follows vim.o.background; or "dark"|"default"|"forest"|...
    background = "transparent",
    width = 1200,
    scale = 2,
    max_jobs = 2,
    extra_args = {},
  },
})
```

All `InlineMarkdown*` highlight groups are defined with `default = true` and can
be overridden by your colorscheme.

## Notes

- Rendered PNGs are cached in `stdpath("cache")/inline-markdown/` keyed by a
  hash of the diagram source and theme settings; unchanged diagrams never
  re-invoke mmdc.
- Diagrams are shown below their source block (the styled source stays
  visible), so you can keep editing while seeing the result.

## License

MIT
