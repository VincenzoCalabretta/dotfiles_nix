# dap_modules reference project

A minimal, self-contained Bazel workspace for trying every local (non-remote)
dap_modules flow end to end: a `cc_binary` debugged via `gdbserver` + local
`gdb`, and a `py_binary` debugged via `debugpy`. See the top-level
[`dap_modules/README.md`](../../README.md) for the full plugin documentation
— this directory is a companion to try it against, not a replacement for
that doc.

```
reference-project/
├── .bazelversion        -- 9.1.0
├── MODULE.bazel          -- rules_cc + rules_python, bzlmod
├── .bazelrc              -- gdbnf / debugpy / (commented) remote-arm64 configs
├── .nvim-dap.lua         -- explicit (but redundant with dap_modules' defaults)
├── cpp/hello_debug.cc    -- cc_binary: loops, prints, has a breakpoint-worthy function
└── python/hello_debug.py -- py_binary: same shape, in Python
```

## Trying it

```sh
cd dap_modules/examples/reference-project
nvim cpp/hello_debug.cc
```

- `<leader>bC` → Telescope picker → `//cpp:hello_debug` → attaches gdb.
  Set a breakpoint on the `squared = counter * counter` line (`<M-b>`),
  `<M-c>` to continue, watch `counter` change on each hit.
- `<leader>bp` → Telescope picker → `//python:hello_debug` → attaches via
  debugpy (requires `pip install debugpy` on whatever `python3` `.bazelrc`'s
  `debugpy` config resolves to on your `PATH`).
- `<leader>bl` re-launches whichever of the two ran last.

Both binaries loop forever, deliberately slowly (`sleep(500ms)`/
`sleep_for(500ms)`), printing each iteration — there's no race to attach
before something interesting happens; `Ctrl-C` the resulting job or `<M-t>`
in Neovim when done.

## What was actually verified

`bazel` isn't installed in the environment this example was authored in, so
the Bazel wiring (`MODULE.bazel`, both `BUILD.bazel` files) has **not** been
run through a real `bazel build`/`bazel run` — treat it as reviewed-by-hand,
not proven, and expect to fix small things (an off syntax detail, a rules_python
API drift) on first real use. What *was* verified directly against real
tools, standing in for what `dap_modules` does under the hood:

- `cpp/hello_debug.cc` compiled with `g++ -g3 -O0 -fno-omit-frame-pointer`,
  run under `gdbserver 127.0.0.1:1234` (matching the `gdbnf` config's
  `--run_under`), and attached with a plain `gdb -ex "target remote ..."` —
  the breakpoint at `compute_step` hit with the correct source line, local
  variable, and backtrace.
- `python/hello_debug.py` runs correctly standalone (`python3
  python/hello_debug.py`). The `debugpy` wrapping itself (`python3 -m
  debugpy --listen ... --wait-for-client`) was **not** exercised, since
  `debugpy` isn't installed in that environment — it follows the exact
  invocation already documented in `dap_modules/README.md`'s "Python —
  debugpy config" section, but hasn't been run end to end here.

If you hit a rough edge getting this to build for real, it's most likely in
the Bazel/bzlmod wiring rather than the C++/Python source files themselves.

## Compatibility with larger monorepos

This example intentionally reuses config names, ports, and `run_under`
shapes that are already common in flight-software/robotics-style Bazel
monorepos that debug over `gdbserver`/`debugpy`:

- `gdbnf` config name, `gdbserver` bound to `:1234`.
- `debugpy` config name, listening on `0.0.0.0:5678`.

These are exactly `dap_modules`' built-in defaults (`project.lua`), so if
your own monorepo already has `.bazelrc` configs with these names and ports
(many do, independently — it's a natural convention), **no `.nvim-dap.lua`
is needed at all**: open Neovim at that repo's root and `<leader>bC`/
`<leader>bp` work immediately.

For remote/cross-compiled boards, the commented-out `remote-arm64` config in
this project's `.bazelrc` is the shape to copy: a `build:<name>` config that
sets `--platforms=...`/`--extra_toolchains=...` to your registered
cross-toolchain plus `--compilation_mode=dbg --strip=never`, and critically
**no `--run_under`** — `dap_modules/remote.lua` starts `gdbserver` itself
over SSH once the cross-compiled binary has been copied to the target. Point
`cpp.remote.bazel_config` at that config name in `.nvim-dap.lua` and add your
board(s) under `cpp.remote.hosts` (see the top-level README's "Remote
deployment over SSH" section for the full schema and an example with two
hosts).
