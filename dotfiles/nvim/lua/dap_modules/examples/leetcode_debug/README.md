# leetcode_debug

A self-contained Bazel workspace that lets `leetcode.nvim` solutions be
debugged with GDB through this repo's own `dap_modules`/`bazel_picker` flow
(`<leader>bd`), instead of only `:Leet run`/`:Leet submit`'s own console.
Like [`../reference-project`](../reference-project), it's a companion to
try `dap_modules` against — see the top-level
[`dap_modules/README.md`](../../README.md) for the full plugin
documentation.

`:LeetDebugPrep` (`../../../leetcode_modules/harness.lua`, bound in
`plugins/leetcode.lua`) reads the currently open question's
`meta_data.params`/`return` (name + LeetCode type per param) and every test
case currently in its testcase popup buffer, and generates one
`solutions/<id>.<slug>_case<n>_harness.cc` + `BUILD.bazel` `cc_binary` per
case — the shape `solutions/0.demo-two-sum*` below demonstrates by hand,
for a single case, ahead of the generator existing.

## How the pieces connect

- `flake.nix` + `.envrc` (`use flake`; needs nix-direnv, e.g.
  `programs.direnv.nix-direnv.enable = true` in your Home Manager config)
  give this directory its own `bazel` (a wrapper around `bazelisk`,
  honoring `.bazelversion`'s `9.1.0` pin), `gcc`, and `gdb` automatically on
  `cd`. No global/manual Bazel install needed.
- Set `$LEETCODE_STORAGE_HOME` (e.g. via `home.sessionVariables` in a
  consuming flake) to point at a `solutions/` directory here — either this
  checkout's own (see the `.gitignore` note below first) or a copy of this
  whole directory elsewhere. `plugins/leetcode.lua` reads that env var and
  passes it as `opts.storage = { home = ... }`, overriding leetcode.nvim's
  default `stdpath("data")/leetcode`.
- leetcode.nvim then writes/opens each problem as
  `solutions/<frontend_id>.<title_slug>.cpp` — a real file inside this
  Bazel workspace, not a scratch buffer. Set a breakpoint in that exact
  buffer and it matches what Bazel compiles; no copy/symlink step needed.
- Each solution needs a small paired `_harness.cc` per test case (a
  `main()` that constructs that case's args and calls into the `Solution`
  class) and a `cc_binary` rule per case in `solutions/BUILD.bazel`, all
  sharing one `cc_library` wrapping the solution file — see
  `demo_two_sum_debug` below for the shape. `dap_modules/bazel.lua`'s
  `bazel query 'kind(cc_binary|cc_test, //...)'` picks these up
  automatically; no picker changes needed on that side.

### If you point `$LEETCODE_STORAGE_HOME` at this checkout directly

`.gitignore` excludes `solutions/[1-9]*` — i.e. any real LeetCode problem
(frontend ids start at 1), so leetcode.nvim writing your actual solve
progress here can't end up silently staged in this generic module-library
repo. Only the tracked `solutions/0.demo-two-sum*` (id `0`, which LeetCode
never assigns) stays tracked. `BUILD.bazel` is *not* gitignored, since
real usage edits it too — but that means it stays a visible diff you'd
have to consciously `git add`, not something that vanishes silently.

## Trying the demo

```sh
cd dap_modules/examples/leetcode_debug
nvim solutions/0.demo-two-sum_harness.cc
```

- `<leader>bd` → Telescope picker → `//solutions:demo_two_sum_debug` →
  attaches gdb.
- Set a breakpoint on the `int first = j;` line in
  `solutions/0.demo-two-sum.cpp` (`<M-b>`), `<M-c>` to continue.
- The demo solution is deliberately buggy (swaps `i`/`j` in the return),
  so stepping through should make the bug obvious — `expected=[0,1] got=`
  will print the swapped pair.

## Using it for real

1. Open any problem with `:Leet` / `:Leet random` / `:Leet daily` etc. — it
   opens as `solutions/<id>.<slug>.cpp` (via `$LEETCODE_STORAGE_HOME`).
2. `:LeetDebugPrep` — generates one `_case<n>_harness.cc` per test case
   currently in the testcase popup, and adds a `cc_library` (once) +
   one `cc_binary` per case to `solutions/BUILD.bazel`. Safe to re-run
   after editing/adding test cases: existing targets aren't duplicated,
   only missing ones get added, and every harness file is refreshed from
   whatever's currently in the popup.
3. `<leader>bd` → pick `//solutions:<slug>_debug_case<n>` for whichever
   case you want to debug → set breakpoints in the solution buffer you're
   actually editing → `<M-c>` to continue.

Supported param/return types (`leetcode_modules/harness.lua`'s `TYPE_MAP`):
`integer`, `integer[]`, `integer[][]`, `long`, `long[]`, `double`, `number`,
`boolean`, `string`, `string[]`, `character`. Anything else (`ListNode`,
`TreeNode`, ...) is refused up front with a clear error rather than
generating code that won't compile.

## What was actually verified

**This workspace's Bazel/Nix wiring**, through the actual `flake.nix`
devShell, run end to end (not simulated):

- `nix flake check` and `nix develop --command bazel --version` — the
  wrapper resolves through `bazelisk`, which downloads and reports `bazel
  9.1.0`, matching `.bazelversion`.
- `bazel build //solutions:demo_two_sum_debug` — succeeded, but only after
  two corrections made from real compiler errors: `cc_binary` has neither a
  `hdrs` nor a `textual_hdrs` attribute (only `cc_library` does), so the
  solution file lives in its own `demo_two_sum_solution` `cc_library` that
  the binary depends on — see `solutions/BUILD.bazel`'s comment.
- `bazel run --config=gdbnf //solutions:demo_two_sum_debug` — initially
  failed with `execv of '/bin/bash' failed: No such file or directory`:
  Bazel's `--run_under` (what `gdbnf`'s config uses to launch under
  `gdbserver`) hardcodes `/bin/bash`, which doesn't exist on NixOS (only
  `/bin/sh` does). Fixed by setting `BAZEL_SH` in the devShell (`flake.nix`)
  to a real bash from nixpkgs — Bazel checks that env var before falling
  back to the hardcoded path. This is a general NixOS+Bazel gap, not
  specific to this project.
- With that fix, `bazel run --config=gdbnf` correctly launched
  `gdbserver :1234`, and a plain `gdb -ex "target remote :1234"` attached,
  hit a breakpoint at `solutions/0.demo-two-sum.cpp:17` (the `int first =
  j;` line), and showed the correct pre-bug values `i=0`/`j=1` — the exact
  mechanism `dap_modules`/`bazel_picker` (`<leader>bd`) uses.

**`leetcode_modules/harness.lua`'s generation logic**, unit-tested
standalone (`leetcode.utils` stubbed out, no real leetcode.nvim/network/
auth needed) against a real, correct Two Sum solution with two test cases:

- Generated harnesses for both cases compiled with `g++ -std=c++17` and
  printed the correct `[0,1]`/`[1,2]`, confirming the
  bracket-notation-to-brace-initializer transform and per-case
  `Solution().twoSum(nums, target)` call generation are correct.
- Re-running against the same two cases left `BUILD.bazel` byte-identical
  (idempotency: still exactly 2 `cc_binary` rules, 1 `cc_library` rule).
- Adding a third test case and re-running added exactly one new
  `cc_binary` rule (`_case3`) without touching the other two or duplicating
  the shared `cc_library`; its harness also compiled and produced the
  correct output.
- A fake `ListNode`-typed param correctly triggered the unsupported-type
  guard: an ERROR notification, and no files written at all.
- The generated two-case `BUILD.bazel` block was also run through a real
  `bazel build //solutions:demo_two_sum_debug //solutions:two_sum_debug_case1
  //solutions:two_sum_debug_case2` (all three targets, mixing the tracked
  demo with freshly generated ones) — succeeded, and both generated
  binaries printed the correct `[0,1]`/`[1,2]` when run directly.

Not yet exercised: `:LeetDebugPrep`/`<leader>bd` invoked from inside a real
leetcode.nvim session (the tests above stub `leetcode.utils.curr_question()`
rather than opening a real problem).
