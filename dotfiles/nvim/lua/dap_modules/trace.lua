-- ~/.config/nvim/lua/dap_modules/trace.lua
-- GDB tracepoint timeline for non-stopping trace collection.
--
-- GDB in DAP mode (-i dap) evaluates `context = "repl"` requests as raw CLI
-- commands and returns their output in resp.result. The MI wrapper
-- `-interpreter-exec console "..."` must NOT be used here — it is MI-only.
--
-- Workflow:
--   1. Session connected and paused (after <leader>bg)
--   2. <leader>bT  — choose “Set tracepoint at cursor”
--   3. <leader>bT  — choose “Start collection”, then <M-c> to resume
--   4. <M-p>        — pause the target (GDB requires this before tstop/tfind)
--   5. <leader>bT  — choose “Show timeline”
--
-- Every tracepoint collects the target's $trace_timestamp trace-state
-- variable. GNU gdbserver supplies it in microseconds; an unsupported target
-- still leaves it unavailable and the timeline falls back to sequence order.

local M = {}

M._buf = nil
M._win = nil

local TRACE_SIGN_NAME = "DapTracepoint"
local TRACE_SIGN_GROUP_PREFIX = "DapTracepoints-"
-- group → buffer → line → sign id. This both prevents duplicate markers when
-- a tracepoint is set twice and lets a dual-session cleanup remove only its
-- own signs.
M._markers = {}

local MAX_FRAMES = 500

local function sign_group(session)
  return TRACE_SIGN_GROUP_PREFIX .. tostring(session.id or "active")
end

local function marker_at_cursor()
  return {
    bufnr = vim.api.nvim_get_current_buf(),
    lnum  = vim.api.nvim_win_get_cursor(0)[1],
  }
end

-- A prompted file:line tracepoint can be marked too. Function locations are
-- resolved by GDB, so only the cursor form can be marked reliably before the
-- command response returns.
local function marker_from_location(location)
  local file, line = location:match("^(.-):(%d+)$")
  if not file or vim.fn.filereadable(file) == 0 then return nil end

  local bufnr = vim.fn.bufadd(vim.fn.fnamemodify(file, ":p"))
  vim.fn.bufload(bufnr)
  return { bufnr = bufnr, lnum = tonumber(line) }
end

-- `actions` is an interactive, multi-line GDB command. DAP evaluate/repl
-- executes one command string at a time, so neither the nvim-dap REPL nor a
-- sequence of evaluate calls can feed its `collect`/`end` lines. Source a
-- short, private command file instead; GDB executes the full tracepoint
-- definition and action list as one CLI operation.
local function write_trace_script(location)
  local path = vim.fn.tempname() .. ".gdb"
  local ok, result = pcall(vim.fn.writefile, {
    "trace " .. location,
    "actions",
    "collect $trace_timestamp",
    "end",
  }, path)
  if not ok or result ~= 0 then
    pcall(vim.fn.delete, path)
    return nil
  end
  return path
end

local function place_marker(session, marker)
  if not marker or not vim.api.nvim_buf_is_valid(marker.bufnr) then return end

  local group = sign_group(session)
  local buffers = M._markers[group] or {}
  local lines = buffers[marker.bufnr] or {}
  if lines[marker.lnum] then return end

  local id = vim.fn.sign_place(0, group, TRACE_SIGN_NAME, marker.bufnr, {
    lnum = marker.lnum,
    priority = 10,
  })
  lines[marker.lnum] = id
  buffers[marker.bufnr] = lines
  M._markers[group] = buffers
end

function M.clear_markers(session)
  if session then
    local group = sign_group(session)
    vim.fn.sign_unplace(group)
    M._markers[group] = nil
    return
  end

  for group in pairs(M._markers) do
    vim.fn.sign_unplace(group)
  end
  M._markers = {}
end

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
-- Exported (along with the two parsers below) purely so
-- tests/trace_spec.lua can assert on GDB CLI output parsing directly,
-- without a live session — this string-scraping is the most fragile part
-- of the module (breaks silently if GDB's CLI output format ever shifts).
function M.parse_int(result)
  return result and tonumber(result:match("=%s*(%d+)")) or 0
end

-- Parse function name from GDB `frame` output.
-- Handles both forms:
--   "#0  FuncName (args) at file.cc:42"        (no address)
--   "#0  0xdeadbeef in FuncName (args) at ..."  (with address)
function M.parse_frame_func(result)
  if not result then return "?" end
  return result:match("%sin%s+(.-)%s*%(")    -- "... in FuncName ("
      or result:match("#%d+%s+(.-)%s*%(")    -- "#0  FuncName ("
      or "?"
end

-- True when a tfind command found no more frames (either via err or output).
function M.tfind_exhausted(err, resp)
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

  local marker = location and marker_from_location(location) or marker_at_cursor()
  location = location or vim.fn.expand("<cword>")
  if location == "" then
    vim.notify("[Trace] No location — move cursor onto a function name or pass one explicitly",
               vim.log.levels.WARN)
    return
  end
  if location:find("[\r\n]") then
    vim.notify("[Trace] Tracepoint location must be a single line", vim.log.levels.WARN)
    return
  end

  local script = write_trace_script(location)
  if not script then
    vim.notify("[Trace] Could not create temporary GDB command file", vim.log.levels.ERROR)
    return
  end

  gdb(session, "source " .. script, function(err)
    pcall(vim.fn.delete, script)
    if err then
      vim.notify("[Trace] Failed: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
    else
      place_marker(session, marker)
      vim.notify("[Trace] Tracepoint set: " .. location
                 .. " (timestamp collection enabled)  →  <leader>bT to start collection",
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
      vim.notify("[Trace] Collection started  →  <M-c> to run; <M-p>, then <leader>bT to view",
                 vim.log.levels.INFO)
    end
  end)
end

function M.tstop()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end
  if not session.stopped_thread_id then
    vim.notify("[Trace] Pause the target (<M-p>) before stopping collection", vim.log.levels.WARN)
    return
  end
  gdb(session, "tstop", function()
    vim.notify("[Trace] Stopped  →  <leader>bT to view", vim.log.levels.INFO)
  end)
end

function M.clear()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end
  gdb(session, "delete tracepoints", function(err)
    if err then
      vim.notify("[Trace] Failed to delete tracepoints: " .. (err.message or vim.inspect(err)),
                 vim.log.levels.ERROR)
    else
      M.clear_markers(session)
      vim.notify("[Trace] All tracepoints deleted", vim.log.levels.INFO)
    end
  end)
end

-- Show tracepoint status in the nvim-dap REPL. Calling session:request()
-- directly would receive the text but discard it, leaving only an empty REPL.
function M.info()
  local session = require("dap").session()
  if not session then vim.notify("No active DAP session", vim.log.levels.WARN); return end
  local repl = require("dap").repl
  repl.open()
  repl.execute("info tracepoints")
end

-- ── Frame collection ──────────────────────────────────────────────────────────

-- Read the frame GDB is currently positioned at (via tfind), append to frames,
-- then advance to the next frame. Terminates when tfind finds no more frames.
local function collect_frames(session, frames, on_done)
  if #frames >= MAX_FRAMES then
    on_done(frames, true)
    return
  end

  -- GNU gdbserver's $trace_timestamp uses microseconds. 0 when the target
  -- does not provide a collected timestamp.
  gdb(session, "print $trace_timestamp", function(_, ts_resp)
    local ts = M.parse_int(ts_resp and ts_resp.result)

    -- Function name from the current frame context.
    gdb(session, "frame", function(_, frame_resp)
      local func = M.parse_frame_func(frame_resp and frame_resp.result)
      table.insert(frames, { ts = ts, func = func })

      -- Advance; both err and output are checked for exhaustion.
      gdb(session, "tfind", function(err, next_resp)
        if M.tfind_exhausted(err, next_resp) then
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
    table.insert(lines, "  ● Was a tracepoint set?          :DapTraceInfo  (or <leader>bT)")
    table.insert(lines, "  ● Was collection started?        :DapTraceStart (or <leader>bT)")
    table.insert(lines, "  ● Does this gdbserver support tracepoints? Check the REPL for errors.")
  else
    local has_ts = frames[1].ts ~= 0
    if has_ts then
      table.insert(lines, string.format("  %-6s  %-20s  %-16s  %s", "#", "Timestamp (μs)", "Delta (ms)", "Function"))
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
  if not session.stopped_thread_id then
    vim.notify("[Trace] Pause the target (<M-p>) before showing the timeline", vim.log.levels.WARN)
    return
  end

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
