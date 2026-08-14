return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      -- You can put any snacks configuration options here
    },
    -- Use 'config' instead of 'opts' for mapping the toggles 
    -- to guarantee Snacks is fully loaded first.
    config = function(_, opts)
      require("snacks").setup(opts)
      
      -- Toggle the profiler
      Snacks.toggle.profiler():map("<leader>pp")
      -- Toggle the profiler highlights
      Snacks.toggle.profiler_highlights():map("<leader>ph")
    end,
    keys = {
      -- Fixed the typo in "Buffer" while we are at it!
      { "<leader>ps", function() Snacks.profiler.scratch() end, desc = "Profiler Scratch Buffer" },
    }
  },
  
  -- optional lualine component to show captured events
  -- when the profiler is running
  --
  -- NOTE: this is the plugin spec that actually drives lualine's setup --
  -- plugins/lualine.lua is entirely commented out, so despite its name it
  -- contributes nothing. Since this spec provides `opts` without a `config`
  -- function, lazy.nvim auto-calls require('lualine').setup(opts) with it.
  -- (plugins/aerial.lua later appends its own component to lualine_x via
  -- get_config()/setup() again, but doesn't touch lualine_c below.)
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "folke/snacks.nvim" }, -- GUARANTEE snacks loads first
    opts = function(_, opts)
      -- Safety check to ensure the sections table exists before inserting
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      table.insert(opts.sections.lualine_x, Snacks.profiler.status())

      -- Show the path relative to the repo root (nearest .git upward)
      -- instead of lualine's default bare filename -- unhelpful when
      -- several open buffers share a basename. Falls back to the plain
      -- filename outside any git repo.
      opts.sections.lualine_c = {
        function()
          local path = vim.api.nvim_buf_get_name(0)
          if path == '' then
            return '[No Name]'
          end
          local git_dir = vim.fs.find('.git', { path = vim.fs.dirname(path), upward = true })[1]
          local rel = git_dir and path:sub(#vim.fs.dirname(git_dir) + 2) or vim.fn.fnamemodify(path, ':t')
          return rel .. '%m%r'
        end,
      }
    end,
  }
}
