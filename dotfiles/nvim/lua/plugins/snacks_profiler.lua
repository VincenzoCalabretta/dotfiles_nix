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
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "folke/snacks.nvim" }, -- GUARANTEE snacks loads first
    opts = function(_, opts)
      -- Safety check to ensure the sections table exists before inserting
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}
      
      table.insert(opts.sections.lualine_x, Snacks.profiler.status())
    end,
  }
}
