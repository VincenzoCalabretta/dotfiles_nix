-- Solve LeetCode problems inside Neovim.
--   First-time setup: log into leetcode.com in a browser, grab the
--   `csrftoken` + `LEETCODE_SESSION` cookies (devtools > Application/
--   Storage > Cookies), then run `:Leet cookie update` and paste
--   "csrftoken=<value>; LEETCODE_SESSION=<value>". Repeat whenever
--   `:Leet` starts failing with an auth error (session expired).
--
--   :Leet              open the dashboard (random/daily/problem list)
--   :Leet daily        open today's problem
--   :Leet run          run against the sample/custom test cases only
--   :Leet test         same as `:Leet run` (alias)
--   :Leet submit       submit for real grading against LeetCode
--   :Leet console      open the run/submit console pop-up manually
--   :Leet lang         change the language for the current question
--   :Leet reset        reset the code section to the default snippet
--   :LeetDebugPrep     generate a Bazel debug harness for the current
--                      question (needs $LEETCODE_STORAGE_HOME set and a
--                      Bazel workspace there -- see leetcode_modules/harness.lua)
--
-- Set $LEETCODE_STORAGE_HOME (e.g. via home.sessionVariables in a consuming
-- flake, matching the COMPILER_EXPLORER_URL pattern in modules/nvim.nix) to
-- point solution files at a Bazel workspace instead of the default
-- stdpath("data")/leetcode, so a debug harness there can build/gdbserver
-- the exact file this plugin writes. Left unset, the default applies.
local storage_home = vim.env.LEETCODE_STORAGE_HOME

return {
  {
    "kawre/leetcode.nvim",
    -- html parser is fetched on demand via treesitter.lua's auto_install,
    -- since nvim-treesitter's main branch doesn't support lazy-loading and
    -- ":TSUpdate" isn't defined yet when this plugin's build step would run.
    cmd = { "Leet", "LeetDebugPrep" },
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-neotest/nvim-nio",
    },
    opts = {
      lang = "cpp",
      storage = storage_home and { home = storage_home } or nil,
    },
    config = function(_, opts)
      require("leetcode").setup(opts)
      vim.api.nvim_create_user_command("LeetDebugPrep", function()
        require("leetcode_modules.harness").prep()
      end, { desc = "leetcode.nvim: generate a Bazel debug harness for the current question" })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
