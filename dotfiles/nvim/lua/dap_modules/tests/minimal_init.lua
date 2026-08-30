-- Minimal runtimepath for running dap_modules' plenary test suite headless.
-- Usage (see run_tests.sh):
--   nvim --headless -u lua/dap_modules/tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory lua/dap_modules/tests { minimal_init = 'lua/dap_modules/tests/minimal_init.lua' }"
--
-- Adds this nvim config's own lua/ tree (so `require("dap_modules.*")`
-- resolves) plus the handful of plugins the code under test actually
-- requires: plenary (test framework), nvim-dap (adapters/dap.run), and
-- telescope + its dap extension (only touched by bazel.lua's picker
-- helpers, not exercised by these unit tests, but present so requiring the
-- modules that reference them doesn't error).
--
-- Plugin paths come from DAP_MODULES_TEST_PLUGIN_PATHS (colon-separated
-- absolute paths) when set -- this is how the flake's
-- `dap-modules-coverage` check runs hermetically, pointing at
-- pkgs.vimPlugins.* store paths instead of a lazy.nvim install. Locally,
-- with no such install (nothing cloned `~/.local/share/nvim/lazy` yet),
-- leave it unset and this falls back to that directory, matching how
-- run_tests.sh/generate_coverage.sh are normally run against a real,
-- already-used Neovim config.

local this_file = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":p")
-- this_file = .../dotfiles/nvim/lua/dap_modules/tests/minimal_init.lua
-- four :h hops up lands on .../dotfiles/nvim, the directory that *contains*
-- lua/ — that's the rtp entry Neovim's require() needs, not lua/ itself.
local nvim_config_root = vim.fn.fnamemodify(this_file, ":h:h:h:h")
vim.opt.rtp:prepend(nvim_config_root)

local override_paths = vim.env.DAP_MODULES_TEST_PLUGIN_PATHS
if override_paths and override_paths ~= "" then
  for _, path in ipairs(vim.split(override_paths, ":", { plain = true, trimempty = true })) do
    vim.opt.rtp:append(path)
  end
else
  local lazy_root = vim.fn.expand("~/.local/share/nvim/lazy")
  for _, name in ipairs({
    "plenary.nvim",
    "nvim-dap",
    "nvim-dap-view",
    "telescope.nvim",
    "telescope-dap.nvim",
  }) do
    local path = lazy_root .. "/" .. name
    if vim.fn.isdirectory(path) == 1 then
      vim.opt.rtp:append(path)
    end
  end
end

-- Defensive: plugin/ files under the paths above are normally auto-sourced
-- during startup since rtp was extended before Neovim reaches that stage,
-- but re-running `:runtime` for plenary's commands is cheap and idempotent.
vim.cmd("runtime! plugin/plenary.vim")

-- Optional line-coverage instrumentation, enabled by generate_coverage.sh
-- via DAP_MODULES_COVERAGE_DIR. Left out of the default run_tests.sh path:
-- debug.sethook("l", ...) plus jit.off() (see coverage.lua) noticeably
-- slows the whole suite down, which isn't worth paying on every run.
--
-- Plenary spawns one nvim subprocess per spec file (test_harness.lua's
-- test_directory), each inheriting this env var and getting its own
-- collector instance, so each process's hits are saved to a PID-named
-- file for generate_coverage.sh to merge afterward.
local coverage_dir = vim.env.DAP_MODULES_COVERAGE_DIR
if coverage_dir and coverage_dir ~= "" then
  local tests_dir = vim.fn.fnamemodify(this_file, ":h")
  local coverage  = dofile(tests_dir .. "/coverage.lua")

  local tracked = vim.fn.glob(nvim_config_root .. "/lua/dap_modules/*.lua", false, true)
  table.insert(tracked, nvim_config_root .. "/lua/bazel_picker.lua")
  coverage.start(tracked)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      coverage.stop()
      coverage.save(string.format("%s/%d.cov.lua", coverage_dir, vim.loop.os_getpid()))
    end,
  })
end
