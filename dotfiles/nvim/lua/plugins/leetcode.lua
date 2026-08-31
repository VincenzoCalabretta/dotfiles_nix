-- Solve LeetCode problems inside Neovim.
--   :Leet    open the LeetCode dashboard
return {
  {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html",
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
