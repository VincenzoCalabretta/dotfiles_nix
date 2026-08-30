-- Minimal, dependency-free line-coverage collector for the dap_modules test
-- suite. There's no luarocks/luacov available in this Nix-managed setup, so
-- this reimplements just enough of that idea: a debug.sethook("l", ...)
-- line tracker restricted to a set of tracked path prefixes, with results
-- serializable to disk -- necessary because plenary spawns one nvim
-- subprocess per spec file (see plenary/test_harness.lua's test_directory),
-- each with its own separate Lua state, so a single in-process hit table
-- can't see across files. generate_coverage.sh merges the per-process
-- files this writes and hands them to render_coverage.lua.
--
-- Known limitation shared with real luacov: Lua/LuaJIT line hooks don't
-- always fire for every source line (e.g. a `local function foo(x)` header
-- line sometimes coalesces with an adjacent line in the bytecode) -- treat
-- the report as a strong signal, not a perfectly precise one.

local M = {}

M.hits = {}
M.tracked_prefixes = {}

local function is_tracked(path)
  for _, prefix in ipairs(M.tracked_prefixes) do
    if path:sub(1, #prefix) == prefix then return true end
  end
  return false
end

local function hook(_, line)
  local info = debug.getinfo(2, "S")
  local source = info and info.source
  if not source or source:sub(1, 1) ~= "@" then return end
  local path = source:sub(2)
  if not is_tracked(path) then return end

  local file_hits = M.hits[path]
  if not file_hits then
    file_hits = {}
    M.hits[path] = file_hits
  end
  file_hits[line] = (file_hits[line] or 0) + 1
end

-- `prefixes`: absolute file paths or directory prefixes to track (an exact
-- file path is just a prefix that only matches itself).
--
-- JIT is turned off for the duration: LuaJIT's trace compiler can skip
-- hook calls for hot loops, which would undercount real coverage. This
-- test suite is small and short-lived, so the perf cost is acceptable.
function M.start(prefixes)
  M.tracked_prefixes = prefixes
  M.hits = {}
  if jit then jit.off() end
  debug.sethook(hook, "l")
end

function M.stop()
  debug.sethook()
  if jit then jit.on() end
end

-- Serializes M.hits to a Lua-loadable file, one per nvim process.
function M.save(path)
  local file = assert(io.open(path, "w"))
  file:write("return {\n")
  for source, lines in pairs(M.hits) do
    file:write(string.format("  [%q] = {\n", source))
    for line, count in pairs(lines) do
      file:write(string.format("    [%d] = %d,\n", line, count))
    end
    file:write("  },\n")
  end
  file:write("}\n")
  file:close()
end

-- Merges every `*.cov.lua` file in `dir` into a single hits table:
-- merged[absolute_path][line_number] = total_hit_count.
function M.merge(dir)
  local merged = {}
  local handle = vim.loop.fs_scandir(dir)
  if not handle then return merged end

  while true do
    local name, typ = vim.loop.fs_scandir_next(handle)
    if not name then break end

    if typ == "file" and name:match("%.cov%.lua$") then
      local chunk = loadfile(dir .. "/" .. name)
      if chunk then
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then
          for source, lines in pairs(data) do
            local dest = merged[source]
            if not dest then
              dest = {}
              merged[source] = dest
            end
            for line, count in pairs(lines) do
              dest[line] = (dest[line] or 0) + count
            end
          end
        end
      end
    end
  end

  return merged
end

return M
