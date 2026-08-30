-- Everything below already matches dap_modules' built-in defaults (see
-- ../../project.lua) -- this file exists to show the schema explicitly for
-- a new project, not because it's required. Delete it and <leader>gc /
-- <leader>gp still work exactly the same.
return {
  cpp = {
    bazel_config   = "gdbnf",
    gdbserver_port = 1234,

    -- Uncomment and point at your own cross-compiled, SSH-reachable board(s)
    -- to try <leader>gd / :DapRemoteDebug. See ../../README.md's "Remote
    -- deployment over SSH" section and this directory's README.md.
    -- remote = {
    --   bazel_config = "remote-arm64",
    --   hosts = {
    --     board_a = { host = "user@board-a.local" },
    --   },
    -- },
  },

  python = {
    bazel_config = "debugpy",
    debugpy_port = 5678,
  },
}
