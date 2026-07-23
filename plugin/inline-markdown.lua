if vim.g.loaded_inline_markdown then return end
vim.g.loaded_inline_markdown = true

vim.api.nvim_create_user_command("InlineMarkdown", function(cmd)
  local action = cmd.fargs[1] or "toggle"
  local im = require("inline-markdown")
  if action == "toggle" then
    im.toggle()
  elseif action == "enable" then
    im.enable()
  elseif action == "disable" then
    im.disable()
  elseif action == "refresh" then
    im.refresh()
  else
    vim.notify("InlineMarkdown: unknown action '" .. action .. "'", vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  complete = function()
    return { "toggle", "enable", "disable", "refresh" }
  end,
  desc = "Inline markdown rendering (toggle|enable|disable|refresh)",
})
