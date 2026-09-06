-- This is entry point for lazy.nvim. Helper modules live in lua/dap_modules/.

local ui = require("dap_modules.ui")

local function dap_picker_menu()
  local choices = {
    { label = "Commands", command = "Telescope dap commands" },
    { label = "Breakpoints", command = "Telescope dap list_breakpoints" },
    { label = "Variables", command = "Telescope dap variables" },
    { label = "Stack frames", command = "Telescope dap frames" },
  }

  vim.ui.select(choices, {
    prompt = "DAP picker:",
    format_item = function(choice) return choice.label end,
  }, function(choice)
    if choice then vim.cmd(choice.command) end
  end)
end

local function trace_menu()
  local trace = require("dap_modules.trace")
  local choices = {
    { label = "Set tracepoint at cursor", action = trace.set },
    {
      label = "Set tracepoint at location…",
      action = function()
        vim.ui.input({ prompt = "Tracepoint location (func or file:line): " }, function(location)
          if location and location ~= "" then trace.set(location) end
        end)
      end,
    },
    { label = "Start collection", action = trace.tstart },
    { label = "Show timeline", action = trace.show },
    { label = "Clear tracepoints", action = trace.clear },
    { label = "Show tracepoint information", action = trace.info },
  }

  vim.ui.select(choices, {
    prompt = "Tracepoint action:",
    format_item = function(choice) return choice.label end,
  }, function(choice)
    if choice then choice.action() end
  end)
end

local core = {
  "mfussenegger/nvim-dap",
  dependencies = {
    "igorlfs/nvim-dap-view",
    "nvim-telescope/telescope-dap.nvim",
    "nvim-telescope/telescope.nvim",
    "theHamsta/nvim-dap-virtual-text",
  },
  keys = {
    -- ── Hot-path: Alt bindings (mnemonic: gdb single-letter commands) ──────────

    { "<M-c>",  function() require("dap").continue()                                   end, desc = "DAP: Continue / Start"      },
    {
      "<M-a>",
      function()
        local dap      = require("dap")
        local sessions = dap.sessions()
        if vim.tbl_isempty(sessions) then
          vim.notify("No active DAP sessions", vim.log.levels.WARN)
          return
        end
        for _, s in ipairs(sessions) do
          s:request("continue", { threadId = s.stopped_thread_id }, function() end)
        end
      end,
      desc = "DAP: Continue all sessions",
    },
    { "<M-t>",  function() require("dap").terminate()                                  end, desc = "DAP: Terminate"             },
    { "<M-b>",  function() require("dap").toggle_breakpoint()                          end, desc = "DAP: Toggle Breakpoint"     },
    { "<M-B>",  function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "DAP: Conditional Breakpoint" },
    { "<M-n>",  function() require("dap").step_over()                                  end, desc = "DAP: Step Over (Next)"      },
    { "<M-s>",  function() require("dap").step_into()                                  end, desc = "DAP: Step Into"             },
    { "<M-o>",  function() require("dap").step_out()                                   end, desc = "DAP: Step Out"              },
    { "<M-r>",  function() require("dap").repl.toggle()                                end, desc = "DAP: Toggle REPL"           },
    { "<M-p>",  function() require("dap").pause()                                      end, desc = "DAP: Pause (interrupt)"       },
    {
      "<M-f>",
      function()
        local session = require("dap").session()
        if not session then
          vim.notify("No active DAP session", vim.log.levels.WARN)
          return
        end
        local frame = session.current_frame
        if not frame or not (frame.source or {}).path then
          -- Diagnostic: show what GDB actually returned so we can build a substitute-path
          local diag = {
            frame_id   = frame and frame.id,
            frame_name = frame and frame.name,
            source     = frame and frame.source,
            line       = frame and frame.line,
          }
          vim.notify("[DAP diag] frame dump:\n" .. vim.inspect(diag), vim.log.levels.WARN)
          vim.notify("No source location for current frame", vim.log.levels.WARN)
          return
        end
        vim.cmd("e " .. vim.fn.fnameescape(frame.source.path))
        vim.api.nvim_win_set_cursor(0, { frame.line, 0 })
        vim.cmd("normal! zz")
      end,
      desc = "DAP: Jump to current frame",
    },
    {
      "<M-g>",
      function()
        local dap      = require("dap")
        local sessions = dap.sessions()
        if vim.tbl_isempty(sessions) then
          vim.notify("No active DAP sessions", vim.log.levels.WARN)
          return
        end
        vim.ui.select(sessions, {
          prompt      = "Select DAP session: ",
          format_item = function(s) return s.config.name end,
        }, function(s)
          if s then dap.set_session(s) end
        end)
      end,
      desc = "DAP: Select Session",
    },

    -- Watch variable under cursor (via GDB MI command)
    {
      "<M-w>",
      function()
        local word = vim.fn.expand("<cexpr>")
        if not word or word == "" then
          vim.notify("No variable under cursor", vim.log.levels.WARN)
          return
        end
        local dap = require("dap")
        if dap.session() then
          dap.repl.execute("-var-create - * " .. word)
          vim.notify("Added watch: " .. word, vim.log.levels.INFO)
        else
          vim.notify("No active debug session", vim.log.levels.WARN)
        end
      end,
      desc = "DAP: Add Watch (cexpr under cursor)",
    },

    -- ── Build / target lifecycle: flat <leader>b bindings ────────────────────
    -- Keep each action at two keys after <leader>; menus replace nested trees.
    {
      "<leader>bg",
      function() require("dap_modules.bazel").connect_dual() end,
      desc = "DAP: Attach to dual gdbservers (:1234 + :1235)",
    },
    {
      "<leader>bC",
      function() require("dap_modules.bazel").launch_test() end,
      desc = "DAP: Debug C++ Target (Telescope)",
    },
    {
      "<leader>bH",
      function() require("dap_modules.remote").launch("cpp") end,
      desc = "DAP: Deploy & Debug Remote C++ Target (SSH)",
    },
    {
      "<leader>bl",
      function() require("dap_modules.bazel").launch_last() end,
      desc = "DAP: Relaunch Last Target",
    },
    {
      "<leader>bp",
      function() require("dap_modules.bazel").launch_python() end,
      desc = "DAP: Debug Python Target (Telescope)",
    },
    {
      "<leader>bP",
      function() require("dap_modules.bazel").launch_python_simple() end,
      desc = "DAP: Debug Python Target (input)",
    },
    {
      "<leader>bu",
      function() require("dap_modules.bazel").launch_rust() end,
      desc = "DAP: Debug Rust Target (Telescope)",
    },
    {
      "<leader>bU",
      function() require("dap_modules.bazel").launch_rust_simple() end,
      desc = "DAP: Debug Rust Target (input)",
    },
    { "<leader>bv", "<cmd>DapViewToggle<cr>", desc = "DAP: Toggle View" },
    { "<leader>bT", trace_menu, desc = "DAP: Tracepoint Actions" },
    { "<leader>b?", dap_picker_menu, desc = "DAP: Open Picker Menu" },
  },

  config = function()
    require('nvim-dap-virtual-text').setup({
      highlight_changed_variables = true,
      show_stop_reason = true,
      virt_text_pos = vim.fn.has('nvim-0.10') == 1 and 'inline' or 'eol',
    })
    local bazel  = require("dap_modules.bazel")
    local config = require("dap_modules.config")
    config.setup(bazel)
  end,
}

return vim.list_extend({ core }, ui)
