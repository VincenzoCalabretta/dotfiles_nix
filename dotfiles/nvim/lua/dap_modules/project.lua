-- ~/.config/nvim/lua/dap_modules/project.lua
-- Loads per-project DAP configuration from .nvim-dap.lua in the project root.
-- The file is read lazily (at launch time, not at Neovim startup) so that
-- changes take effect without restarting the editor.

local M = {}

-- Defaults used when no .nvim-dap.lua is found or fields are omitted.
-- nil container_name means bazel is invoked directly on the host (no Docker).
M.defaults = {
  cpp = {
    container_name = nil,
    gdbserver_port = 1234,
    bazel_config   = "gdbnf",
    bazel_cache    = vim.fn.expand("~/.cache/dev/bazel"),
    bazel_bin      = "bazel",
  },
  python = {
    container_name = nil,
    debugpy_port   = 5678,
    bazel_bin      = "bazel",
    bazel_config   = "debugpy",
    -- List of { localRoot = "...", remoteRoot = "..." } mappings.
    -- Only needed when the container path differs from the host path.
    path_mappings  = {},
  },
  rust = {
      container_name = nil,
      gdbserver_port = 1234,
      bazel_config   = "gdbnf", -- Replace with your Rust debug config if different
      bazel_bin      = "bazel",
    },
}

-- Read and return the merged project config.
-- Always re-reads from disk so changes are picked up without restarting nvim.
function M.load()
  local config_path = vim.fn.getcwd() .. "/.nvim-dap.lua"

  if vim.fn.filereadable(config_path) == 0 then
    return vim.tbl_deep_extend("force", {}, M.defaults)
  end

  local ok, project = pcall(dofile, config_path)
  if not ok then
    vim.notify(
      "nvim-dap: error loading .nvim-dap.lua:\n" .. project,
      vim.log.levels.ERROR
    )
    return vim.tbl_deep_extend("force", {}, M.defaults)
  end

  vim.notify("nvim-dap: loaded project config from .nvim-dap.lua", vim.log.levels.DEBUG)
  return vim.tbl_deep_extend("force", M.defaults, project)
end

return M
