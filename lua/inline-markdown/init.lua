local M = {}

local config = require("inline-markdown.config")
local state = require("inline-markdown.state")

local function render(buf)
  require("inline-markdown.render").render(buf)
end

---Apply/restore window-local options for windows showing `buf`.
---@param buf integer
---@param enable boolean
local function sync_win_options(buf, enable)
  local st = state.get(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if enable then
      st.saved_win_opts[win] = {}
      for opt, value in pairs(config.options.win_options) do
        st.saved_win_opts[win][opt] = vim.wo[win][opt]
        vim.wo[win][opt] = value
      end
    else
      local saved = st.saved_win_opts[win]
      if saved then
        for opt, value in pairs(saved) do
          pcall(function() vim.wo[win][opt] = value end)
        end
        st.saved_win_opts[win] = nil
      end
    end
  end
end

---@param buf integer
local function debounced_render(buf)
  local st = state.get(buf)
  if st.timer then st.timer:stop() end
  st.timer = st.timer or vim.uv.new_timer()
  st.timer:start(config.options.debounce_ms, 0, vim.schedule_wrap(function()
    if state.is_enabled(buf) and vim.api.nvim_buf_is_valid(buf) then render(buf) end
  end))
end

---@param buf integer
local function attach_autocmds(buf)
  local st = state.get(buf)
  st.augroup = vim.api.nvim_create_augroup("InlineMarkdownBuf" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = st.augroup,
    buffer = buf,
    callback = function() debounced_render(buf) end,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufWritePost" }, {
    group = st.augroup,
    buffer = buf,
    callback = function() render(buf) end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = st.augroup,
    buffer = buf,
    callback = function()
      sync_win_options(buf, true)
      render(buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
    group = st.augroup,
    buffer = buf,
    callback = function() M.disable(buf) end,
  })
end

---@param buf integer|nil
function M.enable(buf)
  buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
  local st = state.get(buf)
  if st.enabled then return end

  if not pcall(vim.treesitter.get_parser, buf, "markdown") then
    vim.notify("inline-markdown: markdown treesitter parser not available", vim.log.levels.ERROR)
    return
  end

  st.enabled = true
  require("inline-markdown.highlights").setup()
  sync_win_options(buf, true)
  attach_autocmds(buf)
  render(buf)
end

---@param buf integer|nil
function M.disable(buf)
  buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
  local st = state.get(buf)
  if not st.enabled then return end

  st.enabled = false
  if st.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, st.augroup)
    st.augroup = nil
  end
  sync_win_options(buf, false)
  if vim.api.nvim_buf_is_valid(buf) then
    require("inline-markdown.render").clear(buf)
  end
  require("inline-markdown.mermaid.display").clear(buf)
end

---@param buf integer|nil
function M.toggle(buf)
  buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
  if state.is_enabled(buf) then M.disable(buf) else M.enable(buf) end
end

---Force a re-render; also clears remembered mermaid errors so they retry.
---@param buf integer|nil
function M.refresh(buf)
  buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
  require("inline-markdown.mermaid.cache").clear_errors()
  if state.is_enabled(buf) then render(buf) end
end

---@param buf integer|nil
---@return boolean
function M.is_enabled(buf)
  buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
  return state.is_enabled(buf)
end

---@param opts table|nil
function M.setup(opts)
  config.setup(opts)

  local group = vim.api.nvim_create_augroup("InlineMarkdown", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = config.options.file_types,
    callback = function(ev)
      if config.options.keymap then
        vim.keymap.set("n", config.options.keymap, function() M.toggle(ev.buf) end, {
          buffer = ev.buf,
          desc = "Toggle inline markdown rendering",
        })
      end
      if config.options.render_on_open then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then M.enable(ev.buf) end
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function() require("inline-markdown.highlights").setup() end,
  })
end

return M
