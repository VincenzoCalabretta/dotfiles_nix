-- ~/.config/nvim/lua/dap_modules/ui.lua
-- Plugin specs for nvim-dap-view and telescope-dap.
-- Returns a plain list of lazy.nvim plugin specs; no logic lives here.

return {
  -- ── nvim-dap-view: minimalistic debug UI ────────────────────────────────
  {
    "igorlfs/nvim-dap-view",
    lazy = true,
    ---@module 'dap-view'
    ---@type dapview.Config
    opts = {
      winbar = {
        show = true,
        -- Sections shown in the winbar (left to right)
        sections         = { "scopes", "breakpoints", "watches", "exceptions", "threads", "repl" },
        default_section  = "scopes",
        show_keymap_hints = true,
        base_sections = {
          breakpoints = { label = "Breakpoints", keymap = "B" },
          scopes      = { label = "Scopes",      keymap = "S" },
          exceptions  = { label = "Exceptions",  keymap = "E" },
          watches     = { label = "Watches",     keymap = "W" },
          threads     = { label = "Threads",     keymap = "T" },
          repl        = { label = "REPL",        keymap = "R" },
          sessions    = { label = "Sessions",    keymap = "K" },
          console     = { label = "Console",     keymap = "C" },
        },
        custom_sections = {},
        controls = {
          enabled        = false,
          position       = "right",
          buttons        = {
            "play", "step_into", "step_over", "step_out",
            "step_back", "run_last", "terminate", "disconnect",
          },
          custom_buttons = {},
        },
      },
      windows = {
        size     = 0.5,
        position = "right",
        terminal = {
          size     = 0.5,
          position = "left",
          hide     = {},   -- adapters for which the terminal is always hidden
        },
      },
      icons = {
        collapsed  = "󰅂 ",
        disabled   = "",
        disconnect = "",
        enabled    = "",
        expanded   = "󰅀 ",
        filter     = "󰈲",
        negate     = " ",
        pause      = "",
        play       = "",
        run_last   = "",
        step_back  = "",
        step_into  = "",
        step_out   = "",
        step_over  = "",
        terminate  = "",
      },
      help   = { border = nil },
      render = {
        sort_variables = nil,
        threads = {
          format = function(name, lnum, path)
            return {
              { part = name, separator = " "  },
              { part = path, hl = "FileName",  separator = ":" },
              { part = lnum, hl = "LineNumber" },
            }
          end,
          align = false,
        },
        breakpoints = {
          format = function(line, lnum, path)
            return {
              { part = path, hl = "FileName"   },
              { part = lnum, hl = "LineNumber"  },
              { part = line, hl = true          },
            }
          end,
          align = false,
        },
      },
      switchbuf   = "usetab,uselast",
      auto_toggle = false,
      follow_tab  = false,
    },
  },

  -- ── telescope-dap: DAP pickers inside Telescope ───────────────────────────
  {
    "nvim-telescope/telescope-dap.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("dap")
    end,
    keys = {
      { "<leader>dfc", "<cmd>Telescope dap commands<cr>",         desc = "DAP Commands"    },
      { "<leader>dfb", "<cmd>Telescope dap list_breakpoints<cr>", desc = "DAP Breakpoints" },
      { "<leader>dfv", "<cmd>Telescope dap variables<cr>",        desc = "DAP Variables"   },
      { "<leader>dff", "<cmd>Telescope dap frames<cr>",           desc = "DAP Frames"      },
    },
  },
}
