-- I like pizza
return {
  "stevearc/aerial.nvim",
  lazy = false, -- Load immediately on startup
  priority = 1000, -- Load early
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  -- Optional integrations (uncomment if you use these plugins)
  -- {
  --   "nvim-telescope/telescope.nvim",
  --   optional = true,
  -- },
  -- {
  --   "ibhagwan/fzf-lua",
  --   optional = true,
  -- },
  -- {
  --   "nvim-lualine/lualine.nvim",
  --   optional = true,
  -- },
  -- {
  --   "folke/snacks.nvim",
  --   optional = true,
  -- },
  
  keys = {
    -- Toggle aerial window
    { "<leader>a", "<cmd>AerialToggle!<CR>", desc = "Aerial: Toggle" },
    { "<leader>ao", "<cmd>AerialOpen<CR>", desc = "Aerial: Open" },
    { "<leader>ac", "<cmd>AerialClose<CR>", desc = "Aerial: Close" },
    { "<leader>aO", "<cmd>AerialOpenAll<CR>", desc = "Aerial: Open All" },
    { "<leader>aC", "<cmd>AerialCloseAll<CR>", desc = "Aerial: Close All" },
    
    -- Navigation
    { "<leader>an", "<cmd>AerialNext<CR>", desc = "Aerial: Next Symbol" },
    { "<leader>ap", "<cmd>AerialPrev<CR>", desc = "Aerial: Prev Symbol" },
    { "<leader>ag", "<cmd>AerialGo<CR>", desc = "Aerial: Go to Symbol" },
    
    -- Nav window
    { "<leader>aN", "<cmd>AerialNavToggle<CR>", desc = "Aerial: Toggle Nav Window" },
    
    -- Info
    { "<leader>ai", "<cmd>AerialInfo<CR>", desc = "Aerial: Info" },
    
    -- Telescope integration (if available)
    {
      "<leader>as",
      function()
        if pcall(require, "telescope") then
          require("telescope").extensions.aerial.aerial()
        else
          vim.notify("Telescope not available", vim.log.levels.WARN)
        end
      end,
      desc = "Aerial: Search Symbols (Telescope)",
    },
    
    -- FZF-Lua integration (if available)
    {
      "<leader>af",
      function()
        if pcall(require, "fzf-lua") then
          require("aerial").fzf_lua_picker()
        else
          vim.notify("FZF-Lua not available", vim.log.levels.WARN)
        end
      end,
      desc = "Aerial: Search Symbols (FZF-Lua)",
    },
    
    -- Snacks picker integration (if available)
    {
      "<leader>aS",
      function()
        if pcall(require, "snacks") then
          require("aerial").snacks_picker()
        else
          vim.notify("Snacks.nvim not available", vim.log.levels.WARN)
        end
      end,
      desc = "Aerial: Search Symbols (Snacks)",
    },
  },
  
  opts = {
    -- Priority list of preferred backends for aerial
    backends = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
    
    -- Layout configuration
    layout = {
      -- Window width settings
      max_width = { 40, 0.2 }, -- Lesser of 40 columns or 20% of total
      width = nil,
      min_width = 10,
      
      -- Window-local options for aerial window
      win_opts = {
        winblend = 0,
        winhl = "Normal:NormalFloat,FloatBorder:FloatBorder",
      },
      
      -- Default direction to open the aerial window
      default_direction = "prefer_right",
      
      -- Where to open aerial window
      placement = "window", -- "edge" or "window"
      
      -- Auto-resize to fit content
      resize_to_content = true,
      
      -- Preserve window size equality
      preserve_equality = false,
    },
    
    -- How aerial decides which buffer to display symbols for
    attach_mode = "window", -- "window" or "global"
    
    -- Auto-close events
    close_automatic_events = { "unfocus", "switch_buffer", "unsupported" },
    
    -- Keymaps in aerial window
    keymaps = {
      ["?"] = "actions.show_help",
      ["g?"] = "actions.show_help",
      ["<CR>"] = "actions.jump",
      ["<2-LeftMouse>"] = "actions.jump",
      ["<C-v>"] = "actions.jump_vsplit",
      ["<C-s>"] = "actions.jump_split",
      ["p"] = "actions.scroll",
      ["<C-j>"] = "actions.down_and_scroll",
      ["<C-k>"] = "actions.up_and_scroll",
      ["{"] = "actions.prev",
      ["}"] = "actions.next",
      ["[["] = "actions.prev_up",
      ["]]"] = "actions.next_up",
      ["q"] = "actions.close",
      ["o"] = "actions.tree_toggle",
      ["za"] = "actions.tree_toggle",
      ["O"] = "actions.tree_toggle_recursive",
      ["zA"] = "actions.tree_toggle_recursive",
      ["l"] = "actions.tree_open",
      ["zo"] = "actions.tree_open",
      ["L"] = "actions.tree_open_recursive",
      ["zO"] = "actions.tree_open_recursive",
      ["h"] = "actions.tree_close",
      ["zc"] = "actions.tree_close",
      ["H"] = "actions.tree_close_recursive",
      ["zC"] = "actions.tree_close_recursive",
      ["zr"] = "actions.tree_increase_fold_level",
      ["zR"] = "actions.tree_open_all",
      ["zm"] = "actions.tree_decrease_fold_level",
      ["zM"] = "actions.tree_close_all",
      ["zx"] = "actions.tree_sync_folds",
      ["zX"] = "actions.tree_sync_folds",
    },
    
    -- Lazy load configuration
    lazy_load = true,
    
    -- Performance limits
    disable_max_lines = 10000,
    disable_max_size = 2000000, -- 2MB
    
    -- Filter symbols to display
    filter_kind = {
      "Array",
      "Boolean",
      "Class",
      "Constant",
      "Constructor",
      "Enum",
      "EnumMember",
      "Event",
      "Field",
      "File",
      "Function",
      "Interface",
      "Key",
      "Method",
      "Module",
      "Namespace",
      "Null",
      "Number",
      "Object",
      "Operator",
      "Package",
      "Property",
      "String",
      "Struct",
      "TypeParameter",
      "Variable",
    },
    
    -- Highlight configuration
    highlight_mode = "split_width", -- "split_width", "full_width", "last", or "none"
    highlight_closest = true,
    highlight_on_hover = false,
    highlight_on_jump = 300,
    
    -- Autojump when cursor moves
    autojump = false,
    
    -- Icon configuration
    icons = {},
    
    -- Ignore configuration
    ignore = {
      unlisted_buffers = false,
      diff_windows = true,
      filetypes = {},
      buftypes = "special",
      wintypes = "special",
    },
    
    -- Folding integration
    manage_folds = false,
    link_folds_to_tree = false,
    link_tree_to_folds = true,
    
    -- Use Nerd Font icons
    nerd_font = "auto",
    
    -- Callback when aerial attaches to a buffer
    on_attach = function(bufnr)
      -- Set buffer-local keymaps for navigation
      vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr, desc = "Aerial: Prev Symbol" })
      vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr, desc = "Aerial: Next Symbol" })
      vim.keymap.set("n", "[[", "<cmd>AerialPrevUp<CR>", { buffer = bufnr, desc = "Aerial: Prev Up" })
      vim.keymap.set("n", "]]", "<cmd>AerialNextUp<CR>", { buffer = bufnr, desc = "Aerial: Next Up" })
    end,
    
    -- Callback when symbols are first set
    on_first_symbols = function(bufnr)
      -- Optional: Auto-open aerial for certain filetypes
      -- local ft = vim.bo[bufnr].filetype
      -- if ft == "rust" or ft == "python" then
      --   vim.cmd("AerialOpen")
      -- end
    end,
    
    -- Auto-open configuration
    open_automatic = false,
    -- open_automatic = function(bufnr)
    --   -- Open aerial automatically for files with more than 50 lines
    --   return vim.api.nvim_buf_line_count(bufnr) > 50
    -- end,
    
    -- Command to run after jumping
    post_jump_cmd = "normal! zz",
    
    -- Symbol parsing callback
    post_parse_symbol = function(bufnr, item, ctx)
      -- Filter out symbols or modify them here
      -- Return false to filter out the symbol
      return true
    end,
    
    -- Post-processing callback
    post_add_all_symbols = function(bufnr, items, ctx)
      -- Modify the symbol tree before display
      return items
    end,
    
    -- Close on select
    close_on_select = false,
    
    -- Update events
    update_events = "TextChanged,InsertLeave",
    
    -- Tree guides
    show_guides = true,
    guides = {
      mid_item = "├─",
      last_item = "└─",
      nested_top = "│ ",
      whitespace = "  ",
    },
    
    -- Custom highlight function
    get_highlight = function(symbol, is_icon, is_collapsed)
      -- Return custom highlight group
      -- return "MyHighlight" .. symbol.kind
    end,
    
    -- Floating window configuration
    float = {
      border = "rounded",
      relative = "cursor", -- "cursor", "editor", or "win"
      max_height = 0.9,
      height = nil,
      min_height = { 8, 0.1 },
      override = function(conf, source_winid)
        -- Customize floating window config
        return conf
      end,
    },
    
    -- Navigation window configuration
    nav = {
      border = "rounded",
      max_height = 0.9,
      min_height = { 10, 0.1 },
      max_width = 0.5,
      min_width = { 0.2, 20 },
      win_opts = {
        cursorline = true,
        winblend = 10,
      },
      autojump = false,
      preview = false,
      keymaps = {
        ["<CR>"] = "actions.jump",
        ["<2-LeftMouse>"] = "actions.jump",
        ["<C-v>"] = "actions.jump_vsplit",
        ["<C-s>"] = "actions.jump_split",
        ["h"] = "actions.left",
        ["l"] = "actions.right",
        ["<C-c>"] = "actions.close",
        ["q"] = "actions.close",
      },
    },
    
    -- LSP backend configuration
    lsp = {
      diagnostics_trigger_update = false,
      update_when_errors = true,
      update_delay = 300,
      priority = {
        -- Customize LSP client priority here
        -- pyright = 10,
        -- rust_analyzer = 15,
      },
    },
    
    -- Treesitter backend configuration
    treesitter = {
      update_delay = 300,
    },
    
    -- Markdown backend configuration
    markdown = {
      update_delay = 300,
    },
    
    -- Asciidoc backend configuration
    asciidoc = {
      update_delay = 300,
    },
    
    -- Man page backend configuration
    man = {
      update_delay = 300,
    },
  },
  
  config = function(_, opts)
    -- Setup aerial with options
    require("aerial").setup(opts)
    
    -- Telescope integration setup (if available)
    local ok_telescope, telescope = pcall(require, "telescope")
    if ok_telescope then
      telescope.setup({
        extensions = {
          aerial = {
            col1_width = 4,
            col2_width = 30,
            format_symbol = function(symbol_path, filetype)
              if filetype == "json" or filetype == "yaml" then
                return table.concat(symbol_path, ".")
              else
                return symbol_path[#symbol_path]
              end
            end,
            show_columns = "both", -- "symbols", "lines", or "both"
          },
        },
      })
      telescope.load_extension("aerial")
    end
    
    -- Lualine integration (if available)
    local ok_lualine, lualine = pcall(require, "lualine")
    if ok_lualine then
      local config = lualine.get_config()
      table.insert(config.sections.lualine_x or {}, {
        "aerial",
        sep = " ) ",
        depth = nil,
        dense = false,
        dense_sep = ".",
        colored = true,
      })
      lualine.setup(config)
    end
    
    -- Custom highlight groups (optional)
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        -- Customize aerial highlights
        vim.api.nvim_set_hl(0, "AerialLine", { link = "QuickFixLine" })
        vim.api.nvim_set_hl(0, "AerialLineNC", { bg = "#3d3d3d" })
        vim.api.nvim_set_hl(0, "AerialGuide", { link = "Comment" })
        
        -- Example: Custom highlights for specific symbol kinds
        -- vim.api.nvim_set_hl(0, "AerialClass", { link = "Type" })
        -- vim.api.nvim_set_hl(0, "AerialClassIcon", { link = "Special" })
        -- vim.api.nvim_set_hl(0, "AerialFunction", { link = "Function" })
        -- vim.api.nvim_set_hl(0, "AerialFunctionIcon", { fg = "#cb4b16" })
      end,
    })
    
    -- Trigger highlight setup immediately
    vim.schedule(function()
      vim.cmd("doautocmd ColorScheme")
    end)
  end,
}
