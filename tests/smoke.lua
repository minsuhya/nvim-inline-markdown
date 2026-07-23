-- Headless smoke test: nvim --headless -l tests/smoke.lua
-- Verifies decorations, mermaid detection, caching and the mmdc pipeline.

vim.opt.rtp:prepend(".")

local failed = 0
local function check(desc, ok, extra)
  if ok then
    print(("  PASS  %s"):format(desc))
  else
    failed = failed + 1
    print(("  FAIL  %s%s"):format(desc, extra and (" — " .. extra) or ""))
  end
end

require("inline-markdown").setup({
  mermaid = { scale = 1, width = 600 },
})

-- fresh cache for a deterministic run
local cache = require("inline-markdown.mermaid.cache")
vim.fn.delete(cache.dir(), "rf")

vim.cmd.edit("tests/fixtures/sample.md")
local buf = vim.api.nvim_get_current_buf()

check("filetype is markdown", vim.bo[buf].filetype == "markdown")

-- enable rendering
require("inline-markdown").enable(buf)
check("buffer reports enabled", require("inline-markdown").is_enabled(buf))
check("conceallevel applied", vim.wo.conceallevel == 2)

local ns = require("inline-markdown.state").ns
local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
check("extmarks were created", #marks > 20, "got " .. #marks)

local kinds = { overlay = 0, line_hl = 0, conceal = 0, virt_lines = 0 }
for _, m in ipairs(marks) do
  local d = m[4]
  if d.virt_text_pos == "overlay" then kinds.overlay = kinds.overlay + 1 end
  if d.line_hl_group then kinds.line_hl = kinds.line_hl + 1 end
  if d.conceal then kinds.conceal = kinds.conceal + 1 end
  if d.virt_lines then kinds.virt_lines = kinds.virt_lines + 1 end
end
check("overlay marks (bullets/icons/table)", kinds.overlay >= 10, vim.inspect(kinds))
check("line highlights (headings/code)", kinds.line_hl >= 5, tostring(kinds.line_hl))
check("conceal marks (inline/links)", kinds.conceal >= 5, tostring(kinds.conceal))
check("mermaid pending placeholder", kinds.virt_lines >= 1, tostring(kinds.virt_lines))

-- mermaid detection
local blocks = require("inline-markdown.mermaid.detect").blocks(buf)
check("exactly one mermaid block detected", #blocks == 1, "got " .. #blocks)
if #blocks == 1 then
  check("mermaid content extracted", blocks[1].content:match("flowchart TD") ~= nil)
end

-- wait for mmdc to produce the png (up to 60s: first run may download chromium deps)
local hash = cache.hash(blocks[1].content)
local ok_png = vim.wait(60000, function()
  return cache.exists(hash)
end, 200)
check("mmdc rendered png into cache", ok_png, cache.path(hash))

-- cached second pass: re-render should not create a pending placeholder
require("inline-markdown").refresh(buf)
vim.wait(200)
local marks2 = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
local pending = 0
for _, m in ipairs(marks2) do
  local vl = m[4].virt_lines
  if vl and vl[1] and vl[1][1] and vl[1][1][1]:match("rendering") then pending = pending + 1 end
end
check("no pending placeholder after cache hit", pending == 0, tostring(pending))

-- error path: broken diagram must produce an error, not an infinite retry
local bad = "not a valid mermaid diagram at all {{{"
local bad_hash = cache.hash(bad)
local done = false
require("inline-markdown.mermaid.job").run(bad, bad_hash, function() done = true end)
vim.wait(60000, function() return done end, 200)
check("broken diagram reports error", cache.errors[bad_hash] ~= nil)
check("broken diagram produced no png", not cache.exists(bad_hash))

-- disable restores everything
require("inline-markdown").disable(buf)
local marks3 = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
check("disable clears extmarks", #marks3 == 0, "got " .. #marks3)
check("disable restores conceallevel", vim.wo.conceallevel == 0)

print(failed == 0 and "ALL TESTS PASSED" or ("FAILED: " .. failed))
os.exit(failed == 0 and 0 or 1)
