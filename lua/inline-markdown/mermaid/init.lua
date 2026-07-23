local cache = require("inline-markdown.mermaid.cache")
local config = require("inline-markdown.config")
local detect = require("inline-markdown.mermaid.detect")
local display = require("inline-markdown.mermaid.display")
local job = require("inline-markdown.mermaid.job")
local state = require("inline-markdown.state")

local M = {}

local warned_mmdc = false

---@return boolean
local function mmdc_available()
  if vim.fn.executable(config.options.mermaid.mmdc_path) == 1 then return true end
  if not warned_mmdc then
    warned_mmdc = true
    vim.notify(
      ("inline-markdown: '%s' not found — mermaid rendering disabled (npm i -g @mermaid-js/mermaid-cli)"):format(
        config.options.mermaid.mmdc_path
      ),
      vim.log.levels.WARN
    )
  end
  return false
end

---Render/refresh mermaid diagrams for a buffer.
---Called from render.init after decorations; extmarks in our namespace were
---already cleared, images are pruned here by key.
---@param buf integer
function M.render(buf)
  if not config.options.mermaid.enabled or not mmdc_available() then
    display.clear(buf)
    return
  end

  local seen = {}
  for _, block in ipairs(detect.blocks(buf)) do
    local hash = cache.hash(block.content)
    local key = hash .. ":" .. block.end_row

    if cache.exists(hash) then
      display.show(buf, key, cache.path(hash), block, seen)
    elseif cache.errors[hash] then
      display.error(buf, block, cache.errors[hash])
    else
      display.pending(buf, block)
      job.run(block.content, hash, function()
        -- re-render the whole buffer: cached png (or error) is picked up here
        if state.is_enabled(buf) and vim.api.nvim_buf_is_valid(buf) then
          require("inline-markdown.render").render(buf)
        end
      end)
    end
  end
  display.prune(buf, seen)
end

return M
