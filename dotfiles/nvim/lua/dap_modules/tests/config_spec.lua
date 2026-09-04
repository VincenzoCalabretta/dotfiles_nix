-- Tests for dap_modules/config.lua: dap.adapters/configurations wiring,
-- signs, user commands, and listener registration produced by M.setup().
--
-- M.setup() has global side effects on the real nvim-dap module (adapters,
-- signs, autocommands, user commands), so it's called once here and the
-- resulting state is asserted against, rather than per-test — matching how
-- it's actually used (called once from plugins/dap.lua).

local bazel  = require("dap_modules.bazel")
local config = require("dap_modules.config")
local dap    = require("dap")

config.setup(bazel)

describe("dap_modules.config", function()
  describe("adapters", function()
    it("registers the local gdb adapter ending in `-i dap`", function()
      local adapter = dap.adapters.gdb
      assert.is_table(adapter)
      assert.equals("executable", adapter.type)
      assert.equals("gdb", adapter.command)
      assert.equals("-i", adapter.args[#adapter.args - 1])
      assert.equals("dap", adapter.args[#adapter.args])
    end)

    it("registers gdb_dual with --nx and a longer init timeout", function()
      local adapter = dap.adapters.gdb_dual
      assert.is_table(adapter)
      assert.equals("gdb", adapter.command)
      assert.is_true(vim.tbl_contains(adapter.args, "--nx"))
      assert.equals(30, adapter.options.initialize_timeout_sec)
    end)

    it("registers the debugpy server adapter on 127.0.0.1:5678", function()
      assert.same({ type = "server", host = "127.0.0.1", port = 5678 }, dap.adapters.python)
    end)
  end)

  describe("cpp/c/rust configurations", function()
    it("defines a single attach-to-gdbserver configuration on localhost:1234", function()
      local cfgs = dap.configurations.cpp
      assert.equals(1, #cfgs)
      assert.equals("gdb", cfgs[1].type)
      assert.equals("attach", cfgs[1].request)
      assert.equals("localhost:1234", cfgs[1].target)
    end)

    it("shares the identical configuration table across cpp/c/rust", function()
      assert.equals(dap.configurations.cpp, dap.configurations.c)
      assert.equals(dap.configurations.cpp, dap.configurations.rust)
    end)
  end)

  describe("python configuration", function()
    it("matches the debugpy adapter's host/port", function()
      local cfgs = dap.configurations.python
      assert.equals(1, #cfgs)
      assert.equals("python", cfgs[1].type)
      assert.same({ host = "127.0.0.1", port = 5678 }, cfgs[1].connect)
      assert.is_false(cfgs[1].justMyCode)
    end)
  end)

  describe("signs", function()
    it("defines every DAP sign group", function()
      for _, name in ipairs({
        "DapBreakpoint", "DapBreakpointCondition", "DapBreakpointRejected",
        "DapStopped", "DapLogPoint", "DapTracepoint",
      }) do
        assert.equals(1, #vim.fn.sign_getdefined(name), name .. " should be defined")
      end
    end)
  end)

  describe("user commands", function()
    it("registers the trace, diagnostic, and remote-debug commands", function()
      for _, cmd in ipairs({
        "DapTraceSet", "DapTraceStart", "DapTraceStop", "DapTraceClear",
        "DapTraceInfo", "DapTraceShow", "DapDiagFrame", "DapRemoteDebug",
      }) do
        assert.equals(2, vim.fn.exists(":" .. cmd), cmd .. " should be a user command")
      end
    end)
  end)

  describe("listeners", function()
    it("wires the dap-view auto-open/close, hover, and gdbserver-cleanup listeners", function()
      assert.is_function(dap.listeners.after.event_initialized["dapview_auto_open"])
      assert.is_function(dap.listeners.before.event_terminated["dapview_auto_close"])
      assert.is_function(dap.listeners.before.event_exited["dapview_auto_close"])
      assert.is_function(dap.listeners.after.event_initialized["dap_auto_hover"])
      assert.is_function(dap.listeners.before.event_terminated["dap_auto_hover_cleanup"])
      assert.is_function(dap.listeners.after.event_terminated["kill_gdbserver"])
      assert.is_function(dap.listeners.after.event_exited["kill_gdbserver"])
      assert.is_function(dap.listeners.before.event_terminated["tracepoint_sign_cleanup"])
      assert.is_function(dap.listeners.before.event_exited["tracepoint_sign_cleanup"])
    end)
  end)
end)
