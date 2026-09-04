-- Tests for dap_modules/trace.lua: the GDB CLI output parsers (the most
-- fragile part of the module — it scrapes plain-text GDB output) and the
-- "no active session" guard clause shared by every public function.

local trace = require("dap_modules.trace")
local dap   = require("dap")

describe("dap_modules.trace", function()
  describe("parse_int()", function()
    it("extracts the integer from GDB print output", function()
      assert.equals(42, trace.parse_int("$1 = 42"))
      assert.equals(0, trace.parse_int("$2 = 0"))
    end)

    it("returns 0 for nil or unparseable input", function()
      assert.equals(0, trace.parse_int(nil))
      assert.equals(0, trace.parse_int("no numbers here"))
    end)
  end)

  describe("parse_frame_func()", function()
    it("extracts the function name when GDB includes an address", function()
      assert.equals(
        "compute_step",
        trace.parse_frame_func("#0  0x0000555555555185 in compute_step (counter=3) at hello_debug.cc:9")
      )
    end)

    it("extracts the function name when GDB omits the address", function()
      assert.equals("compute_step", trace.parse_frame_func("#0  compute_step (counter=3) at hello_debug.cc:9"))
    end)

    it('returns "?" for nil or unrecognized output', function()
      assert.equals("?", trace.parse_frame_func(nil))
      assert.equals("?", trace.parse_frame_func("garbage"))
    end)
  end)

  describe("tfind_exhausted()", function()
    it("is exhausted on any error, regardless of the response", function()
      assert.is_true(trace.tfind_exhausted({ message = "boom" }, nil))
    end)

    it("recognizes GDB's various \"no more frames\" phrasings", function()
      for _, phrase in ipairs({
        "No trace frame is currently selected.",
        "tfind: Target failed.",
        "No more frames.",
        "Frame not found.",
      }) do
        -- tfind_exhausted returns the matched substring (truthy, not
        -- necessarily boolean true) on these branches -- see is_truthy.
        assert.is_truthy(trace.tfind_exhausted(nil, { result = phrase }), phrase)
      end
    end)

    it("is not exhausted for an ordinary frame description", function()
      assert.is_falsy(
        trace.tfind_exhausted(nil, { result = "#3  compute_step (counter=7) at hello_debug.cc:9" })
      )
    end)
  end)

  describe("session guard clause", function()
    local orig_session

    before_each(function()
      orig_session = dap.session
      dap.session = function() return nil end
    end)

    after_each(function()
      dap.session = orig_session
    end)

    local cases = {
      { name = "set",    fn = function() trace.set("compute_step") end },
      { name = "tstart", fn = function() trace.tstart() end },
      { name = "tstop",  fn = function() trace.tstop() end },
      { name = "clear",  fn = function() trace.clear() end },
      { name = "info",   fn = function() trace.info() end },
      { name = "show",   fn = function() trace.show() end },
    }

    for _, case in ipairs(cases) do
      it(case.name .. "() warns and no-ops without an active session", function()
        local notified = {}
        local orig_notify = vim.notify
        vim.notify = function(msg, level) table.insert(notified, { msg = msg, level = level }) end

        local ok = pcall(case.fn)

        vim.notify = orig_notify
        assert.is_true(ok, case.name .. "() must not raise without a session")
        assert.is_true(#notified > 0)
        assert.matches("[Nn]o active", notified[1].msg)
        assert.equals(vim.log.levels.WARN, notified[1].level)
      end)
    end
  end)

  describe("running-target guard clause", function()
    local orig_session

    before_each(function()
      orig_session = dap.session
      dap.session = function()
        return {
          -- A running session has no stopped thread. Its request method must
          -- not be reached: GDB rejects tstop/tfind while the inferior runs.
          stopped_thread_id = nil,
          request = function() error("GDB request must not run while target is running") end,
        }
      end
    end)

    after_each(function()
      dap.session = orig_session
    end)

    for _, case in ipairs({
      { name = "tstop", fn = trace.tstop },
      { name = "show",  fn = trace.show },
    }) do
      it(case.name .. "() asks for a pause without issuing a GDB request", function()
        local notified = {}
        local orig_notify = vim.notify
        vim.notify = function(msg, level) table.insert(notified, { msg = msg, level = level }) end

        local ok = pcall(case.fn)

        vim.notify = orig_notify
        assert.is_true(ok, case.name .. "() must not raise while the target runs")
        assert.equals(vim.log.levels.WARN, notified[1].level)
        assert.matches("Pause the target", notified[1].msg)
      end)
    end
  end)

  describe("tracepoint markers", function()
    local orig_session
    local session
    local buf
    local trace_scripts

    before_each(function()
      vim.fn.sign_define("DapTracepoint", { text = "◉" })
      trace_scripts = {}
      session = {
        id = 4242,
        request = function(_, command, args, cb)
          assert.equals("evaluate", command)
          local script = args.expression:match("^source%s+(.+)$")
          if script then
            table.insert(trace_scripts, { path = script, lines = vim.fn.readfile(script) })
          end
          cb(nil, { result = "" })
        end,
      }
      orig_session = dap.session
      dap.session = function() return session end

      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "trace_tick();" })
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_win_set_cursor(0, { 1, 1 })
    end)

    after_each(function()
      trace.clear_markers(session)
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
      dap.session = orig_session
    end)

    it("places one sign at the cursor and removes it after clear", function()
      trace.set()
      trace.set() -- Repeating a tracepoint must not stack duplicate signs.

      assert.equals(2, #trace_scripts)
      assert.same({
        "trace trace_tick",
        "actions",
        "collect $trace_timestamp",
        "end",
      }, trace_scripts[1].lines)
      assert.equals(0, vim.fn.filereadable(trace_scripts[1].path))

      local placed = vim.fn.sign_getplaced(buf, { group = "DapTracepoints-4242" })
      assert.equals(1, #placed[1].signs)
      assert.equals("DapTracepoint", placed[1].signs[1].name)
      assert.equals(1, placed[1].signs[1].lnum)

      trace.clear()
      placed = vim.fn.sign_getplaced(buf, { group = "DapTracepoints-4242" })
      assert.equals(0, #placed[1].signs)
    end)
  end)

  describe("tracepoint info", function()
    local orig_session
    local repl
    local orig_open
    local orig_execute

    before_each(function()
      orig_session = dap.session
      dap.session = function() return { id = 7 } end
      repl = require("dap").repl
      orig_open = repl.open
      orig_execute = repl.execute
    end)

    after_each(function()
      dap.session = orig_session
      repl.open = orig_open
      repl.execute = orig_execute
    end)

    it("executes info tracepoints through the REPL so its result is rendered", function()
      local opened = false
      local command
      repl.open = function() opened = true end
      repl.execute = function(text) command = text end

      trace.info()

      assert.is_true(opened)
      assert.equals("info tracepoints", command)
    end)
  end)
end)
