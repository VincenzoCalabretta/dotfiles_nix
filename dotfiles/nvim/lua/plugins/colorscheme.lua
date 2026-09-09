return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 1000, -- load before other UI plugins so they see the right highlights
    opts = {
      styles = {
        bold = true,
        italic = true,
        transparency = false,
      },
    },
    config = function(_, opts)
      require("rose-pine").setup(opts)
      vim.cmd.colorscheme("rose-pine")
    end,
  },
}
