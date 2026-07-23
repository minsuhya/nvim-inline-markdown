local M = {}

function M.check()
  local health = vim.health
  local config = require("inline-markdown.config")

  health.start("inline-markdown")

  -- treesitter parsers
  for _, lang in ipairs({ "markdown", "markdown_inline" }) do
    if pcall(vim.treesitter.language.add, lang) then
      health.ok("treesitter parser: " .. lang)
    else
      health.error("treesitter parser missing: " .. lang, ":TSInstall " .. lang)
    end
  end

  -- mermaid toolchain
  local mmdc = config.options.mermaid.mmdc_path
  if vim.fn.executable(mmdc) == 1 then
    health.ok("mermaid-cli found: " .. vim.fn.exepath(mmdc))
  else
    health.warn("mermaid-cli (mmdc) not found — diagrams will not render", {
      "npm install -g @mermaid-js/mermaid-cli",
    })
  end

  -- image backend
  if pcall(require, "image") then
    health.ok("image.nvim available")
  else
    health.warn("image.nvim not installed — mermaid diagrams cannot be displayed inline", {
      "add dependency: { '3rd/image.nvim' }",
    })
  end
  if vim.fn.executable("magick") == 1 then
    health.ok("ImageMagick found: " .. vim.fn.exepath("magick"))
  else
    health.warn("ImageMagick 'magick' not found (image.nvim magick_cli processor needs it)", {
      "brew install imagemagick",
    })
  end

  -- terminal environment
  if vim.env.TMUX then
    local out = vim.fn.system({ "tmux", "show", "-Apg", "allow-passthrough" })
    if out:match("allow%-passthrough%s+(all)") or out:match("allow%-passthrough%s+on") then
      health.ok("tmux allow-passthrough is enabled")
    else
      health.warn("tmux detected but allow-passthrough is off — images will not display", {
        "add to ~/.tmux.conf: set -gq allow-passthrough on",
        "then: tmux source-file ~/.tmux.conf",
      })
    end
  end
  local term = vim.env.TERM_PROGRAM or ""
  if term == "WezTerm" then
    health.info("WezTerm detected — ensure enable_kitty_graphics = true in wezterm config")
  end
end

return M
