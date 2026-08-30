-- ~/.config/nvim/lua/dap_modules/project.lua
-- Loads per-project DAP configuration from .nvim-dap.lua in the project root.
-- The file is read lazily (at launch time, not at Neovim startup) so that
-- changes take effect without restarting the editor.

local M = {}

-- Defaults used when no .nvim-dap.lua is found or fields are omitted.
-- nil container_name means bazel is invoked directly on the host (no Docker).
-- Shared shape for cpp/rust `remote` tables (SSH-deployed debugging).
-- See dap_modules/README.md#remote-deployment-over-ssh for the full writeup.
local function remote_defaults()
  return {
    -- Cross-compile .bazelrc config (e.g. "remote-arm64"). Required: remote
    -- debugging is refused until this is set, since there is no sane default
    -- cross-toolchain config to fall back to.
    bazel_config  = nil,
    -- Base directory created on the target; each target gets its own
    -- subdirectory under this path (see remote.lua's `sanitize()`), so
    -- deploys never collide and `rsync --delete` only ever prunes stale
    -- files belonging to that one target.
    workdir       = "/tmp/nvim-dap-deploy",
    -- Local gdb binary used to attach. Override with a cross/multiarch gdb
    -- (e.g. "gdb-multiarch") when the target architecture differs from the
    -- development machine.
    gdb_bin       = "gdb",
    gdbserver_bin = "gdbserver",
    -- Used both as the gdbserver bind port on the target and the local port
    -- an SSH -L forward exposes it on. A single value is fine because only
    -- one remote debug session runs at a time.
    port          = 1234,
    -- Named hosts, e.g.:
    --   hosts = {
    --     board_a = { host = "user@board-a.local" },
    --     board_b = { host = "user@10.0.0.5", ssh_opts = { "-i", "~/.ssh/id_board_b" } },
    --   }
    hosts         = {},
  }
end

M.defaults = {
  cpp = {
    container_name = nil,
    gdbserver_port = 1234,
    bazel_config   = "gdbnf",
    bazel_cache    = vim.fn.expand("~/.cache/dev/bazel"),
    bazel_bin      = "bazel",
    remote         = remote_defaults(),
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
      bazel_cache    = vim.fn.expand("~/.cache/dev/bazel"),
      remote         = remote_defaults(),
    },
}

-- Read and return the merged project config.
-- Always re-reads from disk so changes are picked up without restarting nvim.
--
-- Note the vim.deepcopy() below: vim.tbl_deep_extend only recurses into keys
-- present on *both* sides. For a key that exists only in M.defaults (e.g. an
-- untouched `python` table when the project file only configures `cpp`), the
-- "merged" result would otherwise hold the very same table object as
-- M.defaults — so a caller mutating a field on the returned config would
-- silently corrupt the shared defaults for the rest of the Neovim session.
function M.load()
  local config_path = vim.fn.getcwd() .. "/.nvim-dap.lua"

  if vim.fn.filereadable(config_path) == 0 then
    return vim.deepcopy(M.defaults)
  end

  local ok, project = pcall(dofile, config_path)
  if not ok then
    vim.notify(
      "nvim-dap: error loading .nvim-dap.lua:\n" .. project,
      vim.log.levels.ERROR
    )
    return vim.deepcopy(M.defaults)
  end

  vim.notify("nvim-dap: loaded project config from .nvim-dap.lua", vim.log.levels.DEBUG)
  return vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), project)
end

return M
