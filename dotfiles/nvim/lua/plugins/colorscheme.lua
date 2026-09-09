return {
  {
    "rebelot/kanagawa.nvim",
    priority = 1000, -- load before other UI plugins so they see the right highlights
    opts = {
      compile = false,
      undercurl = true,
      transparent = false,
      dimInactive = false,
      terminalColors = true,
      theme = "wave", -- also: "dragon" (darker), "lotus" (light)
    },
    config = function(_, opts)
      require("kanagawa").setup(opts)
      vim.cmd.colorscheme("kanagawa")
    end,
  },
}
