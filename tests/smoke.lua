-- Headless smoke test: nvim --headless -l tests/smoke.lua
-- Verifies decorations, mermaid detection, caching and the mmdc pipeline.

vim.opt.rtp:prepend(".")

local failed = 0
local skipped = 0
local function check(desc, ok, extra)
  if ok then
    print(("  PASS  %s"):format(desc))
  else
    failed = failed + 1
    print(("  FAIL  %s%s"):format(desc, extra and (" — " .. extra) or ""))
  end
end

---Record a check that could not run, so a missing dependency is visible in the
---log instead of silently shrinking the suite.
local function skip(desc, why)
  skipped = skipped + 1
  print(("  SKIP  %s — %s"):format(desc, why))
end

-- mmdc drives a headless chromium, which needs --no-sandbox on most CI runners;
-- MERMAID_PUPPETEER_CONFIG lets the workflow point mmdc at such a config.
local mermaid_opts = { scale = 1, width = 600 }
if vim.env.MERMAID_PUPPETEER_CONFIG then
  mermaid_opts.extra_args = { "-p", vim.env.MERMAID_PUPPETEER_CONFIG }
end

require("inline-markdown").setup({ mermaid = mermaid_opts })

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
-- the placeholder is only emitted when mmdc exists to render into it
if vim.fn.executable("mmdc") == 1 then
  check("mermaid pending placeholder", kinds.virt_lines >= 1, tostring(kinds.virt_lines))
else
  skip("mermaid pending placeholder", "mmdc is not installed")
end

-- mermaid detection
local blocks = require("inline-markdown.mermaid.detect").blocks(buf)
check("exactly one mermaid block detected", #blocks == 1, "got " .. #blocks)
if #blocks == 1 then
  check("mermaid content extracted", blocks[1].content:match("flowchart TD") ~= nil)
end

-- Probe the pipeline with a diagram known to be valid (up to 60s: the first run
-- may download chromium deps). cache.errors records mmdc stderr, so a chromium
-- launch failure is indistinguishable from a diagram syntax error — without
-- this probe the error-path assertions below pass even when nothing renders at
-- all, which is exactly how a fully broken mmdc went unnoticed in CI.
local mmdc_ok, mmdc_err
do
  local probe = "flowchart TD\n  probe --> ok"
  local settled = false
  require("inline-markdown.mermaid.job").run(probe, cache.hash(probe), function(ok, err)
    settled, mmdc_ok, mmdc_err = true, ok, err
  end)
  if not vim.wait(60000, function() return settled end, 200) then
    mmdc_err = "mmdc did not settle within 60s"
  end
end
if mmdc_ok then
  check("mmdc pipeline usable", true)
  -- the fixture diagram was queued by enable(); it should reach the cache too
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
else
  local why = mmdc_err or "mmdc unavailable"
  skip("mmdc pipeline usable", why)
  skip("mmdc rendered png into cache", why)
  skip("no pending placeholder after cache hit", why)
  skip("broken diagram reports error", why)
  skip("broken diagram produced no png", why)
end

-- GFM extras (default preset): callout badge + recolored bars
local function count_marks(pred)
  local n = 0
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    if pred(m[4]) then n = n + 1 end
  end
  return n
end
check("callout badge rendered", count_marks(function(d)
  return d.virt_text and d.virt_text[1] and d.virt_text[1][1]:match("Note") ~= nil
end) >= 1)

-- github preset: underlines + closed table borders
require("inline-markdown").disable(buf)
require("inline-markdown").setup({ style = { preset = "github" }, mermaid = mermaid_opts })
require("inline-markdown").enable(buf)
check("github preset enabled", require("inline-markdown").is_enabled(buf))
check("heading underline virt line", count_marks(function(d)
  return d.virt_lines and not d.virt_lines_above and d.virt_lines[1]
    and d.virt_lines[1][1] and d.virt_lines[1][1][1]:match("^──") ~= nil
end) >= 2)
check("table top border (virt_lines_above)", count_marks(function(d)
  return d.virt_lines_above and d.virt_lines[1] and d.virt_lines[1][1][1]:match("┌") ~= nil
end) >= 1)
check("table bottom border", count_marks(function(d)
  return d.virt_lines and d.virt_lines[1] and d.virt_lines[1][1][1]:match("└") ~= nil
end) >= 1)
check("heading accent bar (inline)", count_marks(function(d)
  return d.virt_text and d.virt_text[1] and d.virt_text[1][1] == "█ "
end) >= 1)
-- a bar list gives each level its own glyph, so depth never needs counting
check("heading accent bars differ per level", count_marks(function(d)
  return d.virt_text and d.virt_text[1] and d.virt_text[1][1] == "▌ "
end) >= 1)
-- a bar string still repeats one glyph per depth (h2 ▎, h3 ▎▎, …)
require("inline-markdown").disable(buf)
require("inline-markdown").setup({
  style = { preset = "github", headings = { bar = "▎" } },
  mermaid = mermaid_opts,
})
require("inline-markdown").enable(buf)
check("heading accent bar (repeated string)", count_marks(function(d)
  return d.virt_text and d.virt_text[1] and d.virt_text[1][1] == "▎▎"
end) >= 1)

-- restore default preset config for the teardown assertions
require("inline-markdown").setup({ mermaid = mermaid_opts })

-- disable restores everything
require("inline-markdown").disable(buf)
local marks3 = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
check("disable clears extmarks", #marks3 == 0, "got " .. #marks3)
check("disable restores conceallevel", vim.wo.conceallevel == 0)

local summary = failed == 0 and "ALL TESTS PASSED" or ("FAILED: " .. failed)
print(skipped > 0 and (summary .. (" (%d skipped)"):format(skipped)) or summary)
os.exit(failed == 0 and 0 or 1)
