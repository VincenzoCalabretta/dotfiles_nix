-- ~/.config/nvim/lua/dap_modules/config.lua
-- DAP adapter setup, debug configurations, and all event listeners.
-- Called once from the nvim-dap plugin spec's `config` function.
--
-- C++ configuration is static (attaches to localhost:1234 via GDB).
-- Python configuration is dynamic: port and path mappings are read from
-- .nvim-dap.lua at the moment `dap.continue()` is called, so project-specific
-- settings are always fresh without restarting Neovim.

local M = {}

function M.setup(bazel)
  local dap = require("dap")

  -- ── Logging ────────────────────────────────────────────────────────────────
  -- Log file: vim.fn.stdpath("cache") .. "/dap.log"  (:DapShowLog to open it)
  dap.set_log_level("DEBUG")

  -- ── Signs ──────────────────────────────────────────────────────────────────
  vim.fn.sign_define("DapBreakpoint",          { text = "●", texthl = "DiagnosticError"                       })
  vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn"                        })
  vim.fn.sign_define("DapBreakpointRejected",  { text = "○", texthl = "DiagnosticInfo"                        })
  vim.fn.sign_define("DapStopped",             { text = "→", texthl = "DiagnosticWarn", linehl = "CursorLine" })
  vim.fn.sign_define("DapLogPoint",            { text = "◎", texthl = "DiagnosticInfo"                        })

  -- ── Adapters ───────────────────────────────────────────────────────────────

  local _iex         = "-iex"
  local _stdcxx_src  = "source " .. vim.fn.stdpath('config') .. "/gdb/stdcxx_printers.py"
  local _encore_src  = "source " .. vim.fn.stdpath('config') .. "/gdb/encore_printers.py"

  -- GDB (C++ via gdbserver)
  dap.adapters.gdb = {
    type    = "executable",
    command = "gdb",
    args    = { _iex, _stdcxx_src, _iex, _encore_src, "-i", "dap" },
  }

  -- GDB for SIL sessions: --nx skips ~/.gdbinit to avoid init-file conflicts
  -- when two gdb processes start concurrently (FSW :1234 + SIM :1235).
  -- -iex runs before --nx takes effect so printers still load.
  -- initialize_timeout_sec is raised because gdb can be slow to attach when
  -- the target process is already running under gdbserver.
  dap.adapters.gdb_sil = {
    type    = "executable",
    command = "gdb",
    args    = { _iex, _stdcxx_src, _iex, _encore_src, "--nx", "-i", "dap" },
    options = { initialize_timeout_sec = 30 },
  }

  -- debugpy (Python)
  dap.adapters.python = {
    type = "server",
    host = "127.0.0.1",
    port = 5678,
  }

  -- ── C++ debug configurations ───────────────────────────────────────────────
  local workspace      = vim.fn.getcwd()
  local bazel_cache    = vim.fn.expand("~/.cache/dev/bazel")
  local printer_cmd    = "source " .. vim.fn.stdpath('config') .. '/gdb/stdcxx_printers.py'
  local encore_cmd     = "source " .. vim.fn.stdpath('config') .. '/gdb/encore_printers.py'

  dap.configurations.cpp = {
    {
      name    = "Attach to gdbserver",
      type    = "gdb",
      request = "attach",
      target  = "localhost:1234",
      cwd     = workspace,
      setupCommands = {
        {
          description    = "Canary: confirm setupCommands run",
          text           = "set $nvim_dap_setup_ran = 1",
          ignoreFailures = false,
        },
        {
          description    = "Enable pretty-printing",
          text           = "-enable-pretty-printing",
          ignoreFailures = false,
        },
        {
          description    = "Load libstdc++ pretty-printers",
          text           = printer_cmd,
          ignoreFailures = true,
        },
        {
          description    = "Load Encore project pretty-printers",
          text           = encore_cmd,
          ignoreFailures = true,
        },
        {
          description    = "Show dynamic types for polymorphic pointers",
          text           = "set print object on",
          ignoreFailures = true,
        },
        {
          description    = "Set source directory",
          text           = "directory " .. workspace,
          ignoreFailures = false,
        },
        {
          description    = "Set debug file directory",
          text           = "set debug-file-directory " .. bazel_cache,
          ignoreFailures = true,
        },
      },
    },
  }

  dap.configurations.c    = dap.configurations.cpp

  -- Rust uses the same GDB config as C++; pretty-printers are loaded globally
  -- via ~/.gdbinit (gdb_lookup.register_printers on gdb.current_progspace()).
  dap.configurations.rust = dap.configurations.cpp

  -- ── Python debug configurations ────────────────────────────────────────────
  dap.configurations.python = {
    {
      name    = "Attach to debugpy (Bazel)",
      type    = "python",
      request = "attach",
      connect = {
        host = "127.0.0.1",
        port = 5678,
      },
      pathMappings = {},
      justMyCode   = false,
    },
  }

  -- ── Listeners: DAP View UI ─────────────────────────────────────────────────
  -- pcall guards prevent nvim-dap-view internal errors (e.g. "has active
  -- session" on re-attach) from propagating and killing the DAP session.
  dap.listeners.after.event_initialized["dapview_auto_open"] = function()
    pcall(vim.cmd, "DapViewClose")  -- close any stale view from a prior session
    pcall(vim.cmd, "DapViewOpen")
  end
  dap.listeners.before.event_terminated["dapview_auto_close"] = function()
    pcall(vim.cmd, "DapViewClose")
  end
  dap.listeners.before.event_exited["dapview_auto_close"] = function()
    pcall(vim.cmd, "DapViewClose")
  end

  -- ── Listeners: hover evaluation ────────────────────────────────────────────
  -- Shows the value of the expression under the cursor in a small
  -- non-focusable floating window after `updatetime` ms of inactivity.
  dap.listeners.after.event_initialized["dap_auto_hover"] = function()
    vim.api.nvim_create_autocmd("CursorHold", {
      group = vim.api.nvim_create_augroup("dap_hover", { clear = true }),
      callback = function()
        if not require("dap").session() then return end

        local word = vim.fn.expand("<cexpr>")
        if not word or word == "" then return end

        require("dap").session():evaluate(word, function(err, response)
          if err or not response or not response.result then return end

          local text = word .. " = " .. response.result
          local buf  = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })

          local win = vim.api.nvim_open_win(buf, false, {
            relative  = "cursor",
            row       = 1,
            col       = 0,
            width     = math.min(60, #text + 2),
            height    = 1,
            style     = "minimal",
            border    = "rounded",
            focusable = false,
            noautocmd = true,
          })

          vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
            buffer   = vim.api.nvim_get_current_buf(),
            once     = true,
            callback = function()
              pcall(vim.api.nvim_win_close, win, true)
            end,
          })
        end)
      end,
    })

    vim.opt.updatetime = 500
  end

  local function cleanup_hover()
    pcall(vim.api.nvim_del_augroup_by_name, "dap_hover")
    vim.opt.updatetime = 4000
  end
  dap.listeners.before.event_terminated["dap_auto_hover_cleanup"] = cleanup_hover
  dap.listeners.before.event_exited["dap_auto_hover_cleanup"]     = cleanup_hover

  -- ── Listeners: process lifetime ────────────────────────────────────────────
  local function deferred_kill()
    vim.defer_fn(function() bazel.kill_gdbserver() end, 500)
  end
  dap.listeners.after.event_terminated["kill_gdbserver"] = deferred_kill
  dap.listeners.after.event_exited["kill_gdbserver"]     = deferred_kill

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function() bazel.kill_gdbserver() end,
  })

  -- ── Tracepoint timeline ────────────────────────────────────────────────────
  -- Non-stopping execution trace: set tracepoints, tstart, let the system run,
  -- then DapTraceShow to collect all frames into a timestamped timeline buffer.
  local trace = require("dap_modules.trace")

  vim.api.nvim_create_user_command("DapTraceSet", function(o)
    trace.set(o.args ~= "" and o.args or nil)
  end, { nargs = "?", desc = "Set GDB tracepoint at location (default: <cword>)" })

  vim.api.nvim_create_user_command("DapTraceStart", function()
    trace.tstart()
  end, { desc = "Start non-stopping trace collection (tstart)" })

  vim.api.nvim_create_user_command("DapTraceStop", function()
    trace.tstop()
  end, { desc = "Stop trace collection (tstop)" })

  vim.api.nvim_create_user_command("DapTraceClear", function()
    trace.clear()
  end, { desc = "Delete all GDB tracepoints" })

  vim.api.nvim_create_user_command("DapTraceInfo", function()
    trace.info()
  end, { desc = "Show tracepoint status in the GDB REPL" })

  vim.api.nvim_create_user_command("DapTraceShow", function()
    trace.show()
  end, { desc = "Stop collection and display the execution timeline" })

  -- ── Diagnostic: dump raw DAP frame + stackTrace response ──────────────────
  -- :DapDiagFrame — run when stopped to see what GDB reports for source paths.
  -- Look for `source.path` (or its absence) and `source.sourceReference`.
  -- Use this to build the correct `set substitute-path` commands.
  vim.api.nvim_create_user_command("DapDiagFrame", function()
    local session = dap.session()
    if not session then
      vim.notify("No active DAP session", vim.log.levels.WARN)
      return
    end

    local frame = session.current_frame
    vim.notify("[DapDiag] current_frame:\n" .. vim.inspect(frame), vim.log.levels.INFO)

    local thread_id = session.stopped_thread_id
    if not thread_id then
      vim.notify("[DapDiag] No stopped thread — is the session paused?", vim.log.levels.WARN)
      return
    end

    session:request("stackTrace", { threadId = thread_id, levels = 3 }, function(err, resp)
      if err then
        vim.notify("[DapDiag] stackTrace error: " .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end
      local frames = resp and resp.stackFrames or {}
      local out = {}
      for i, f in ipairs(frames) do
        table.insert(out, string.format(
          "[%d] %s  source=%s  line=%s",
          i, tostring(f.name),
          vim.inspect(f.source),
          tostring(f.line)
        ))
      end
      vim.notify("[DapDiag] stackTrace:\n" .. table.concat(out, "\n"), vim.log.levels.INFO)
    end)

    -- Also show GDB's current source search directories
    session:request("evaluate", {
      expression = "-interpreter-exec console \"info directories\"",
      context    = "repl",
    }, function(_, resp)
      if resp then
        vim.notify("[DapDiag] GDB directories:\n" .. vim.inspect(resp), vim.log.levels.INFO)
      end
    end)
  end, { desc = "Dump DAP frame + stackTrace for source-path diagnosis" })
end

return M
