-- Explicit but redundant with dap_modules' built-in defaults (see the
-- public repo's dap_modules/project.lua and its reference-project example).
return {
  cpp = {
    bazel_config   = "gdbnf",
    gdbserver_port = 1234,
  },
}
