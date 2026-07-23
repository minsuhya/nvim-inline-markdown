local cache = require("inline-markdown.mermaid.cache")
local config = require("inline-markdown.config")

local M = {}

---@type table<string, boolean> running jobs keyed by hash
local running = {}
---@type { hash: string, content: string, cb: fun(ok: boolean, err: string|nil) }[]
local queue = {}

local function active_count()
  return vim.tbl_count(running)
end

local function dequeue()
  local item = table.remove(queue, 1)
  if item then M.run(item.content, item.hash, item.cb) end
end

---Render mermaid source to the cache png for `hash` via mmdc (async).
---@param content string
---@param hash string
---@param cb fun(ok: boolean, err: string|nil) called on the main loop
function M.run(content, hash, cb)
  if running[hash] then return end
  if active_count() >= config.options.mermaid.max_jobs then
    queue[#queue + 1] = { hash = hash, content = content, cb = cb }
    return
  end

  cache.ensure_dir()
  local m = config.options.mermaid
  local src = vim.fs.joinpath(cache.dir(), hash .. ".mmd")
  local okw, err = pcall(vim.fn.writefile, vim.split(content, "\n", { plain = true }), src)
  if not okw then
    cb(false, "failed to write temp file: " .. tostring(err))
    return
  end

  local cmd = {
    m.mmdc_path,
    "-i", src,
    "-o", cache.path(hash),
    "-b", m.background,
    "-t", config.mermaid_theme(),
    "-w", tostring(m.width),
    "-s", tostring(m.scale),
    "--quiet",
  }
  vim.list_extend(cmd, m.extra_args)

  running[hash] = true
  local ok_spawn, job = pcall(vim.system, cmd, { text = true, timeout = 30000 }, function(out)
    vim.schedule(function()
      running[hash] = nil
      vim.uv.fs_unlink(src)
      if out.code == 0 and cache.exists(hash) then
        cache.errors[hash] = nil
        cb(true, nil)
      else
        local msg = (out.stderr and out.stderr ~= "") and out.stderr or ("mmdc exited with code " .. out.code)
        cache.errors[hash] = msg
        cb(false, msg)
      end
      dequeue()
    end)
  end)

  if not ok_spawn then
    running[hash] = nil
    local msg = "failed to spawn mmdc: " .. tostring(job)
    cache.errors[hash] = msg
    cb(false, msg)
    dequeue()
  end
end

---@param hash string
---@return boolean
function M.is_running(hash)
  return running[hash] == true
end

return M
