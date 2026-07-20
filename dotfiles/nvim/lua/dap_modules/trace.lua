-- ~/.config/nvim/lua/dap_modules/trace.lua
-- GDB tracepoint timeline for SIL debugging.
--
-- GDB in DAP mode (-i dap) evaluates `context = "repl"` requests as raw CLI
-- commands and returns their output in resp.result. The MI wrapper
-- `-interpreter-exec console "..."` must NOT be used here — it is MI-only.
--
-- Workflow:
--   1. Session connected and paused (after <leader>gs)
--   2. <leader>gtt  — place tracepoint on function under cursor
--   3. <leader>gts  — tstart; FSW/SIM resume and log hits non-intrusively
--   4. <leader>gtv  — tstop + collect all frames → timeline buffer
--
-- Timestamps come from $trace_timestamp (hardware trace unit).
-- If unavailable the timeline shows sequence order only.

local M = {}

M._buf = nil
M._win = nil

local MAX_FRAMES = 500

-- ── GDB helpers ───────────────────────────────────────────────────────────────

-- Raw GDB CLI command via DAP evaluate/repl.
-- Output is captured in resp.result (GDB DAP uses to_string=True internally).
local function gdb(session, cmd, cb)
  session:request("evaluate", {
    expression = cmd,
    context    = "repl",
  }, cb or function() end)
end

-- Parse the integer value out of GDB print output: "$N = 42" → 42
local function parse_int(result)
  return result and tonumber(result:match("=%s*(%d+)")) or 0
end

-- Parse function name from GDB `frame` output.
-- Handles both forms:
--   "#0  FuncName (args) at file.cc:42"        (no address)
--   "#0  0xdeadbeef in FuncName (args) at ..."  (with address)
local function parse_frame_func(result)
  if not result then return "?" end
  return result:match("%sin%s+(.-)%s*%(")    -- "... in FuncName ("
      or result:match("#%d+%s+(.-)%s*%(")    -- "#0  FuncName ("
      or "?"
end

-- True when a tfind command found no more frames (either via err or output).
local function tfind_exhausted(err, resp)
  if err then return true end
  local r = resp and resp.result or ""
  return r:match("[Nn]o trace frame")
      or r:match("[Ff]ailed")
      or r:match("[Nn]o more")
      or r:match("[Nn]ot found")
end

-- ── Tracepoint commands ───────────────────────────────────────────────────────

function M.set(location)
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end

  location = location or vim.fn.expand("<cword>")
  if location == "" then
    vim.notify("[Trace] No location — move cursor onto a function name or pass one explicitly",
               vim.log.levels.WARN)
    return
  end

  gdb(session, "trace " .. location, function(err)
    if err then
      vim.notify("[Trace] Failed: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
    else
      vim.notify("[Trace] Tracepoint set: " .. location .. "  →  <leader>gts to start collection",
                 vim.log.levels.INFO)
    end
  end)
end

function M.tstart()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end
  gdb(session, "tstart", function(err)
    if err then
      vim.notify("[Trace] tstart failed: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
    else
      vim.notify("[Trace] Collection started  →  <leader>gtv when done", vim.log.levels.INFO)
    end
  end)
end

function M.tstop()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end
  gdb(session, "tstop", function()
    vim.notify("[Trace] Stopped  →  <leader>gtv to view", vim.log.levels.INFO)
  end)
end

function M.clear()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end
  gdb(session, "delete tracepoints", function()
    vim.notify("[Trace] All tracepoints deleted", vim.log.levels.INFO)
  end)
end

-- Show tracepoint status; output appears in the GDB REPL (opens it).
function M.info()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end
  gdb(session, "info tracepoints", function() end)
  require("dap").repl.open()
end

-- ── Frame collection ──────────────────────────────────────────────────────────

-- Read the frame GDB is currently positioned at (via tfind), append to frames,
-- then advance to the next frame. Terminates when tfind finds no more frames.
local function collect_frames(session, frames, on_done)
  if #frames >= MAX_FRAMES then
    on_done(frames, true)
    return
  end

  -- Timestamp (nanoseconds). 0 when the gdbserver doesn't supply it.
  gdb(session, "print $trace_timestamp", function(_, ts_resp)
    local ts = parse_int(ts_resp and ts_resp.result)

    -- Function name from the current frame context.
    gdb(session, "frame", function(_, frame_resp)
      local func = parse_frame_func(frame_resp and frame_resp.result)
      table.insert(frames, { ts = ts, func = func })

      -- Advance; both err and output are checked for exhaustion.
      gdb(session, "tfind", function(err, next_resp)
        if tfind_exhausted(err, next_resp) then
          on_done(frames, false)
        else
          collect_frames(session, frames, on_done)
        end
      end)
    end)
  end)
end

-- ── Timeline buffer ───────────────────────────────────────────────────────────

local function render(session_name, frames, truncated)
  if not M._buf or not vim.api.nvim_buf_is_valid(M._buf) then
    M._buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M._buf].buftype   = "nofile"
    vim.bo[M._buf].bufhidden = "wipe"
    vim.bo[M._buf].swapfile  = false
    vim.api.nvim_buf_set_name(M._buf, "DAP Trace Timeline")
  end

  local lines  = {}
  local suffix = truncated and ("  ⚠ capped at " .. MAX_FRAMES) or ""
  local header = string.format("GDB Trace Timeline  [%s]  %d frames%s  (q: close  r: refresh)",
                               session_name, #frames, suffix)
  table.insert(lines, header)
  table.insert(lines, string.rep("─", math.max(#header, 72)))

  if #frames == 0 then
    table.insert(lines, "")
    table.insert(lines, "  No frames collected.")
    table.insert(lines, "  ● Was a tracepoint set?          :DapTraceInfo  (or <leader>gti)")
    table.insert(lines, "  ● Was collection started?        :DapTraceStart (or <leader>gts)")
    table.insert(lines, "  ● Does this gdbserver support tracepoints? Check the REPL for errors.")
  else
    local has_ts = frames[1].ts ~= 0
    if has_ts then
      table.insert(lines, string.format("  %-6s  %-20s  %-16s  %s", "#", "Timestamp (ns)", "Delta (μs)", "Function"))
    else
      table.insert(lines, string.format("  %-6s  %-52s  %s", "#", "Function", "(no timestamps)"))
    end
    table.insert(lines, "  " .. string.rep("─", 70))

    local prev_ts = frames[1].ts
    for i, f in ipairs(frames) do
      if has_ts then
        local delta = i == 1 and "—" or string.format("%.3f", (f.ts - prev_ts) / 1000.0)
        table.insert(lines, string.format("  %-6d  %-20s  %-16s  %s", i, tostring(f.ts), delta, f.func))
        if f.ts ~= 0 then prev_ts = f.ts end
      else
        table.insert(lines, string.format("  %-6d  %s", i, f.func))
      end
    end
  end

  vim.bo[M._buf].modifiable = true
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, lines)
  vim.bo[M._buf].modifiable = false

  local win_valid = M._win and vim.api.nvim_win_is_valid(M._win)
  if not win_valid then
    local src_win = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    M._win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M._win, M._buf)
    vim.api.nvim_win_set_width(M._win, 96)
    vim.api.nvim_set_current_win(src_win)
  end

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, M._win, true)
    M._win = nil
  end, { buffer = M._buf, silent = true, nowait = true })

  vim.keymap.set("n", "r", function() M.show() end,
    { buffer = M._buf, silent = true, nowait = true })
end

-- ── Public: collect and display ───────────────────────────────────────────────

function M.show()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end

  local name = (session.config and session.config.name) or "unknown"

  -- tstop is idempotent; safe to call even if already stopped.
  gdb(session, "tstop", function()
    gdb(session, "tfind start", function(err, resp)
      -- An error here means no trace data at all (tstart was never called,
      -- or the tracepoint was never hit, or gdbserver lacks tracepoint support).
      if err then
        vim.notify("[Trace] No trace data — was tstart called and a tracepoint hit? ("
                   .. (err.message or "unknown error") .. ")", vim.log.levels.WARN)
        vim.schedule(function() render(name, {}, false) end)
        return
      end

      local result = resp and resp.result or ""
      if result:match("[Nn]o trace frame") or result:match("[Ff]ailed") then
        vim.notify("[Trace] No trace frames found", vim.log.levels.WARN)
        vim.schedule(function() render(name, {}, false) end)
        return
      end

      collect_frames(session, {}, function(frames, truncated)
        vim.schedule(function() render(name, frames, truncated) end)
      end)
    end)
  end)
end

return M
