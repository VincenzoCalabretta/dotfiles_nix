return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- load before other UI plugins so they see the right highlights
    opts = {
      flavour = "mocha", -- also: "latte" (light), "frappe", "macchiato"
      transparent_background = false,
      integrations = {
        cmp = true,
        gitsigns = true,
        telescope = true,
        treesitter = true,
        native_lsp = { enabled = true },
        mason = true,
        dap = true,
        dap_ui = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
