-- Solve LeetCode problems inside Neovim.
--   :Leet    open the LeetCode dashboard
return {
  {
    "kawre/leetcode.nvim",
    -- html parser is fetched on demand via treesitter.lua's auto_install,
    -- since nvim-treesitter's main branch doesn't support lazy-loading and
    -- ":TSUpdate" isn't defined yet when this plugin's build step would run.
    cmd = "Leet",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-neotest/nvim-nio",
    },
    opts = {
      lang = "cpp",
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
