return {
  {
    "folke/tokyonight.nvim",
    priority = 1000, -- load before other UI plugins so they see the right highlights
    opts = {
      style = "night", -- also: "storm", "moon", "day" (light)
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },
}
