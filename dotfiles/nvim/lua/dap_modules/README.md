# nvim-dap Bazel Integration

Modular DAP (Debug Adapter Protocol) configuration for Neovim that debugs Bazel
targets in C++, Python, and Rust — with first-class support for running the
build inside a **devcontainer** (Docker), or cross-compiling and deploying to
a **remote host over SSH** (see [Remote deployment over SSH](#remote-deployment-over-ssh)).

---

## Architecture

```
lua/
├── plugins/dap.lua          ← lazy.nvim entry point; all keymaps live here
├── bazel_picker.lua         ← standalone build/run/test picker (bazel_picker)
└── dap_modules/
    ├── bazel.lua            ← debugger launchers (gdbserver / debugpy)
    ├── config.lua           ← DAP adapter registration + event listeners
    ├── project.lua          ← reads per-project .nvim-dap.lua config
    ├── remote.lua           ← cross-compile + SSH deploy + gdbserver attach
    ├── ui.lua               ← lazy.nvim specs for nvim-dap-view + telescope-dap
    ├── tests/               ← plenary.nvim unit tests + coverage tooling (see Testing below)
    └── examples/
        └── reference-project/  ← standalone Bazel workspace to try dap_modules against
```

`project.lua` is the integration point: at launch time it reads `.nvim-dap.lua`
from the current working directory, so you can change settings without
restarting Neovim.

---

## Dependencies

| Plugin | Purpose |
|---|---|
| `mfussenegger/nvim-dap` | Core DAP client |
| `igorlfs/nvim-dap-view` | Debug UI (scopes, breakpoints, watches, REPL) |
| `nvim-telescope/telescope.nvim` | Fuzzy target picker |
| `nvim-telescope/telescope-dap.nvim` | DAP-specific Telescope extensions |

System tools required on the **host** (or in PATH inside the container):

| Tool | Used for |
|---|---|
| `gdb` | C++ and Rust debugging (DAP MI mode) |
| `gdbserver` | Launched by the Bazel debug config inside the container |
| `python3` + `debugpy` | Python debugging |
| `docker` | Only needed when `container_name` is set |
| `bazel` | Querying and building targets |
| `ssh`, `rsync` | Only needed for [remote deployment over SSH](#remote-deployment-over-ssh) |

---

## Installation

### 1. Copy the modules

Place the `dap_modules/` directory and `bazel_picker.lua` under your
`~/.config/nvim/lua/` tree, then add `plugins/dap.lua` to wherever your
lazy.nvim plugin specs live.

### 2. Register with lazy.nvim

```lua
-- In your lazy.nvim setup, include:
{ import = "plugins.dap" }
```

lazy.nvim will automatically pull in `nvim-dap-view` and `telescope-dap.nvim`
from `dap_modules/ui.lua` via `vim.list_extend`.

### 3. Register `bazel_picker` (optional but recommended)

`bazel_picker.lua` is a standalone module for build/test/run operations
(not only debugging). Add it to your init or a dedicated plugin spec:

```lua
-- e.g. in lua/plugins/bazel.lua or init.lua
require("bazel_picker").setup()
```

You can override keymaps:

```lua
require("bazel_picker").setup({
  keymaps = {
    build  = "<leader>bb",
    test   = "<leader>bt",
    run    = "<leader>br",
    debug  = "<leader>bd",
    toggle_auto_rebuild = "<leader>ba",
    show_recent         = "<leader>bh",
    clear_recent        = "<leader>bc",
  },
})
```

---

## Reference Bazel project

`examples/reference-project/` is a minimal, self-contained Bazel workspace
(a `cc_binary` and a `py_binary`, both debuggable) for trying the local
`gdbnf`/`debugpy` flows end to end without needing your own Bazel project
first. See [its README](examples/reference-project/README.md) for how to
run it and what was (and wasn't) actually verified when it was authored, and
for notes on why its config names generalize to real monorepos.

`examples/leetcode_debug/` is a second, more specific example: a Bazel
workspace wired to `plugins/leetcode.lua`'s `:LeetDebugPrep`, so
leetcode.nvim solutions can be debugged through this same `gdbnf` flow
instead of only leetcode.nvim's own run/submit console. Ships its own
`flake.nix` devShell (Bazel via `bazelisk`, `gcc`, `gdb`) rather than
relying on this repo's own toolchain. See
[its README](examples/leetcode_debug/README.md).

---

## Per-project configuration: `.nvim-dap.lua`

Create a `.nvim-dap.lua` file at the **root of each repository**. The file is
executed with `dofile()` and must return a table. Any key you omit falls back to
the defaults shown below.

Open Neovim from that same repository root: the integration looks only for
`$PWD/.nvim-dap.lua`; it does not walk up parent directories. The file is Lua,
not JSON or YAML, and it is re-read each time a Bazel launcher starts. Treat it
as trusted project code: do not open an untrusted repository and launch DAP.

### New-project quick start

For a new C++ project that builds and runs on the host, create this file and
replace `gdbnf` with the debug configuration from the project's `.bazelrc`:

```lua
-- <project-root>/.nvim-dap.lua
return {
  cpp = {
    bazel_config   = "gdbnf",
    gdbserver_port = 1234,
    bazel_bin      = "bazel", -- use "bazelisk" here when appropriate
    bazel_cache    = vim.fn.expand("~/.cache/bazel"),
  },
}
```

Then add a matching `.bazelrc` configuration (shown in
[Required `.bazelrc` configs](#required-bazelrc-configs)), start Neovim from
the project root, and use `<leader>gc` to select a C++ target. The launcher
executes `bazel run --config=gdbnf <target>`, waits for its `gdbserver`, and
attaches GDB.

For Python or Rust, add the corresponding `python` or `rust` table from the
full example below. Tables are merged with the defaults, so a project only
needs to specify values it changes.

### Minimal host-only example

```lua
-- .nvim-dap.lua  (no devcontainer)
return {
  cpp = {
    bazel_config = "gdbnf",   -- matches a --config in your .bazelrc
    gdbserver_port = 1234,
  },
  python = {
    bazel_config = "debugpy",
    debugpy_port = 5678,
  },
  rust = {
    bazel_config = "gdbnf",
    gdbserver_port = 1234,
  },
}
```

### Full devcontainer example

```lua
-- .nvim-dap.lua  (build + debug inside a Docker devcontainer)
return {
  cpp = {
    container_name = "dev",          -- name of the running container
    bazel_config   = "gdbnf",
    gdbserver_port = 1234,
    bazel_bin      = "bazel",
    bazel_cache    = "/root/.cache/bazel",  -- path *inside* the container
  },
  python = {
    container_name = "dev",
    bazel_config   = "debugpy",
    debugpy_port   = 5678,
    bazel_bin      = "bazel",
    -- Map container paths back to host paths so the editor can open source files.
    -- Required when the workspace is mounted at a different path in the container.
    path_mappings  = {
      {
        localRoot  = vim.fn.getcwd(),          -- e.g. /home/user/myproject
        remoteRoot = "/workspace/myproject",   -- path inside the container
      },
    },
  },
  rust = {
    container_name = "dev",
    bazel_config   = "gdbnf",
    gdbserver_port = 1234,
    bazel_bin      = "bazel",
  },
}
```

### Remote-target example

A project that cross-compiles for two embedded boards and debugs them over
SSH (see [Remote deployment over SSH](#remote-deployment-over-ssh) for the
full explanation of each field):

```lua
-- .nvim-dap.lua  (cross-compiled binaries deployed to boards over SSH)
return {
  cpp = {
    -- Unrelated to remote.* below: still used if you ALSO build/debug
    -- host-native targets from this same repo with <leader>gc.
    bazel_config   = "gdbnf",
    gdbserver_port = 1234,

    remote = {
      -- .bazelrc config that selects the cross toolchain/platform (see
      -- "C++ / Rust — cross-compile config" below). No --run_under here:
      -- gdbserver is started over SSH, not by `bazel run`.
      bazel_config  = "remote-arm64",

      -- Per-target subdirectory created under this path on whichever host
      -- is selected, e.g. /srv/nvim-dap-deploy/apps_web_controller.
      workdir       = "/srv/nvim-dap-deploy",

      -- These boards run a Cortex-A53 (aarch64); the dev machine is x86_64,
      -- so a plain "gdb" can't read the binary. Debian/Ubuntu: `apt install
      -- gdb-multiarch`.
      gdb_bin       = "gdb-multiarch",
      gdbserver_bin = "gdbserver",
      port          = 1234,

      hosts = {
        -- Bench unit wired to the dev machine's LAN.
        bench = {
          host = "board@10.0.1.42",
        },
        -- Second unit, reachable via a ~/.ssh/config Host alias; a
        -- non-default key is supplied explicitly here as an example of
        -- ssh_opts (usually unnecessary if ~/.ssh/config already sets
        -- IdentityFile for the alias).
        rig_b = {
          host     = "board@rig-b",
          ssh_opts = { "-i", "~/.ssh/id_rig_b" },
        },
      },
    },
  },

  rust = {
    remote = {
      bazel_config  = "remote-arm64",
      workdir       = "/srv/nvim-dap-deploy",
      gdb_bin       = "gdb-multiarch",
      port          = 1234,
      hosts = {
        bench = { host = "board@10.0.1.42" },
        rig_b = { host = "board@rig-b", ssh_opts = { "-i", "~/.ssh/id_rig_b" } },
      },
    },
  },
}
```

With this in place: `<leader>gd` (or `:DapRemoteDebug cpp`) opens the Telescope
target picker, then — since two hosts are configured — prompts to choose
`bench` or `rig_b`, then builds, deploys, and attaches. `:DapRemoteDebug rust`
does the same for `rust_binary`/`rust_test` targets. `<leader>gl` redeploys and
reattaches to whichever target+host combination ran last.

### All keys and their defaults

```lua
-- project.lua defaults (shown for reference; override in .nvim-dap.lua)
{
  cpp = {
    container_name = nil,           -- nil = run on host, string = docker exec
    gdbserver_port = 1234,
    bazel_config   = "gdbnf",
    bazel_cache    = "~/.cache/dev/bazel",
    bazel_bin      = "bazel",
    remote = {                      -- see #remote-deployment-over-ssh
      bazel_config  = nil,          -- cross-compile config; required to use remote debugging
      workdir       = "/tmp/nvim-dap-deploy",
      gdb_bin       = "gdb",        -- override with a cross/multiarch gdb if needed
      gdbserver_bin = "gdbserver",
      port          = 1234,
      hosts         = {},           -- { name = { host = "user@host", ssh_opts = {...} } }
    },
  },
  python = {
    container_name = nil,
    debugpy_port   = 5678,
    bazel_config   = "debugpy",
    bazel_bin      = "bazel",
    path_mappings  = {},            -- list of { localRoot, remoteRoot }
  },
  rust = {
    container_name = nil,
    gdbserver_port = 1234,
    bazel_config   = "gdbnf",
    bazel_bin      = "bazel",
    bazel_cache    = "~/.cache/dev/bazel",
    remote = { --[[ same shape as cpp.remote ]] },
  },
}
```

`container_name` changes where the **Bazel command** is run; it is not a DAP
host setting. C++ and Rust sessions always attach to a port on the local
machine. For a service running on a separate device, use an SSH port forward as
described below.

---

## Remote deployment over SSH

`remote.lua` automates the whole loop for a Bazel target that has to run on a
device other than the machine (or container) Neovim itself is on — a board, a
VM, or any host reachable over SSH. One action (`<leader>gd` or
`:DapRemoteDebug`):

1. Cross-compiles the target on the dev machine: `bazel build --config=<cfg>
   <target>` (never `bazel run` — the host usually can't execute a
   foreign-arch binary).
2. Resolves the exact build output path with `bazel cquery ...
   --output=starlark`.
3. `rsync`s the binary and its `.runfiles` tree (if any) to the chosen host.
4. Starts `gdbserver` on that host and tunnels its port back over the *same*
   SSH connection (`ssh -L <port>:127.0.0.1:<port> host 'gdbserver ...'`).
5. Attaches a local `gdb` to `localhost:<port>`.

See [Remote-target example](#remote-target-example) above for a full
`.nvim-dap.lua`, and [C++ / Rust — cross-compile config](#c--rust--cross-compile-config-remote)
for the matching `.bazelrc` entries.

### Prerequisites

- A working `bazel build --config=<cfg> //target` that cross-compiles for the
  target's architecture. Setting up the platform/toolchain registration
  itself is a Bazel concern outside this integration's scope.
- Passwordless SSH access to each host (key in an agent, or set up via
  `~/.ssh/config` — `ssh_opts` in `.nvim-dap.lua` is only for cases that
  config can't express, e.g. a one-off identity file).
- `rsync` installed on both the dev machine and the target.
- A local `gdb` that understands the target's architecture. If the target is
  a different arch than the dev machine (the common case), install a
  multiarch/cross gdb (e.g. `gdb-multiarch` on Debian/Ubuntu) and set
  `remote.gdb_bin` to it.
- The target must have enough free disk for the deployed binary plus its
  runfiles.

### Configuration

Add a `remote` table under `cpp` (and/or `rust`) in `.nvim-dap.lua`:

```lua
cpp = {
  remote = {
    bazel_config  = "remote-arm64",  -- required: your cross-compile .bazelrc config
    workdir       = "/srv/nvim-dap-deploy",
    gdb_bin       = "gdb-multiarch",
    gdbserver_bin = "gdbserver",
    port          = 1234,
    hosts = {
      bench = { host = "board@10.0.1.42" },
      rig_b = { host = "board@rig-b", ssh_opts = { "-i", "~/.ssh/id_rig_b" } },
    },
  },
},
```

`deploy_and_debug()` refuses to run (with a clear error) until `bazel_config`
is set — there is no sane default cross-toolchain config to fall back to.

### Using it

- `<leader>gd` — Telescope picker over `cc_binary`/`cc_test` targets, then (if
  more than one host is configured) `vim.ui.select` to choose which host,
  then build → deploy → attach.
- `:DapRemoteDebug` / `:DapRemoteDebug cpp` — same as `<leader>gd`.
- `:DapRemoteDebug rust` — same pipeline over `rust_binary`/`rust_test`
  targets and `rust.remote`.
- `<leader>gl` — re-runs the whole pipeline (rebuild + redeploy + reattach)
  for whichever target+host combination ran last, persisted the same way the
  local launchers already persist their last target.
- `<M-t>` (Terminate) and `VimLeavePre` kill the SSH job exactly like they
  kill a local gdbserver/debugpy job today — this also tears down the port
  tunnel and (via SIGHUP to the remote shell) the remote `gdbserver` process.

### Why deploy a binary you also built locally?

`gdb`, running locally, needs symbols. On the local/devcontainer launchers in
`bazel.lua`, GDB auto-discovers the executable because the path gdbserver
reports (via `qXfer:exec-file:read`) happens to also exist on the host — same
machine, or an identically-mounted container volume. On a genuinely separate
remote host that path never exists locally, so `M.attach()` adds an explicit
setup command:

```lua
{ text = "file " .. local_artifact_path, ignoreFailures = false }
```

pointing GDB at the *local* copy of the binary it just deployed — same bytes,
so the DWARF matches exactly. This is the one substantive difference from the
local/container attach flow; everything else (pretty-printers, `directory`,
`debug-file-directory`) is the same `bazel.gdb_setup_commands()` helper all
three flows (local, dual-target, remote) now share.

### Runfiles

Step 3 rsyncs `<artifact>.path` and, if it exists, `<artifact>.path ..
".runfiles"` with `-L` (dereference symlinks) and `--delete`. Bazel runfiles
directories are normally a tree of symlinks back into the execroot, which are
meaningless on a different host — `-L` copies the real file contents instead.
`--delete` is safe because each target gets its own subdirectory under
`remote.workdir` (sanitized from the target label), so it only ever prunes
files belonging to that one target. Repeated deploys of the same target are
fast: rsync only transfers what changed.

### Troubleshooting a remote session

Run `:DapShowLog` (writes to `stdpath("cache") .. "/dap.log"`, set to DEBUG in
`config.lua`) for the GDB/DAP protocol traffic, and watch the `:messages` for
the `[Remote] ...` notifications each pipeline step prints — they name exactly
which of build / cquery / mkdir / rsync / gdbserver failed.

### Manual attach (no build/deploy step)

For the simpler case of an already-running `gdbserver` you started by hand —
someone else's session, a one-off debug, or a binary this integration didn't
build — skip `remote.lua` entirely and forward the port yourself:

```sh
# On the target device (already has the binary):
gdbserver 127.0.0.1:1234 /opt/my-app/bin/my-app --target-argument
# or, to attach to a process already running:
gdbserver 127.0.0.1:1234 --attach 4242
```

```sh
# On the dev machine, in a separate terminal:
ssh -N -L 1234:127.0.0.1:1234 user@target.example
```

Then in Neovim, `<M-c>` → **Attach to gdbserver** (the static config in
`config.lua`, connects to `localhost:1234`). For a non-default port or extra
setup commands (e.g. `set substitute-path`), call `dap.run()` directly:

```vim
:lua << EOF
require("dap").run({
  name = "Target gdbserver",
  type = "gdb",
  request = "attach",
  target = "localhost:2345",
  cwd = vim.fn.getcwd(),
  setupCommands = {
    { text = "directory " .. vim.fn.getcwd(), ignoreFailures = false },
    { text = "set substitute-path /build-agent/workspace " .. vim.fn.getcwd(), ignoreFailures = true },
  },
})
EOF
```

If stack frames refer to build-machine paths, use `:DapDiagFrame` to inspect
them, then add an appropriate `set substitute-path` as above.

---

## Required `.bazelrc` configs

The launcher calls `bazel run --config=<bazel_config> <target>`, so the Bazel
config referenced in `.nvim-dap.lua` must exist in your `.bazelrc`.

### C++ / Rust — gdbserver config

```
# .bazelrc
build:gdbnf --compilation_mode=dbg
build:gdbnf --copt=-O0
build:gdbnf --copt=-g3
build:gdbnf --copt=-fno-omit-frame-pointer
build:gdbnf --strip=never
# Your Bazel rule wraps the binary with gdbserver:
run:gdbnf --run_under="gdbserver localhost:1234"
```

> The ready-pattern that triggers the DAP attach is `"Listening on port 1234"`.
> If your gdbserver prints a different message, adjust `start_cpp()` in
> `bazel.lua`.

### Python — debugpy config

```
# .bazelrc
build:debugpy --compilation_mode=dbg
# Your py_binary entry-point must launch debugpy:
#   python -m debugpy --listen 0.0.0.0:5678 --wait-for-client <your_script.py>
run:debugpy --run_under="python -m debugpy --listen 0.0.0.0:5678 --wait-for-client"
```

> The ready-pattern is `"Listening on"`. debugpy prints this to stderr, which
> the launcher monitors.

### C++ / Rust — cross-compile config (remote)

Used by [Remote deployment over SSH](#remote-deployment-over-ssh). Unlike the
local `gdbnf` config above, this one has **no `--run_under`** — `remote.lua`
starts `gdbserver` itself, over SSH, after copying the binary to the target:

```
# .bazelrc
build:remote-arm64 --platforms=//platforms:arm64-linux    # your toolchain registration
build:remote-arm64 --compilation_mode=dbg
build:remote-arm64 --copt=-O0
build:remote-arm64 --copt=-g3
build:remote-arm64 --copt=-fno-omit-frame-pointer
build:remote-arm64 --strip=never
```

> `--platforms=...` is a placeholder: point it at whatever platform/toolchain
> definition your workspace already registers for the target architecture.
> This integration only calls `bazel build --config=<this>`; it does not set
> up cross-compilation itself.

---

## Devcontainer setup

### Overview

When `container_name` is set in `.nvim-dap.lua`, every `bazel` invocation is
prefixed with:

```
docker exec -i <container_name> bash -c "cd <cwd> && bazel run --config=<cfg> <target>"
```

Neovim itself runs on the **host**. The DAP client (nvim-dap) connects back to
`127.0.0.1:<port>`, so the container must expose the debug port to the host.

### Port forwarding

gdbserver and debugpy both bind to `0.0.0.0` inside the container. You need the
port mapped to the host at container startup:

```sh
docker run -it \
  -p 1234:1234 \   # gdbserver (C++ / Rust)
  -p 5678:5678 \   # debugpy (Python)
  -v $(pwd):/workspace/myproject \
  --name dev \
  my-dev-image
```

Or in `docker-compose.yml`:

```yaml
services:
  dev:
    image: my-dev-image
    container_name: dev
    ports:
      - "1234:1234"   # gdbserver
      - "5678:5678"   # debugpy
    volumes:
      - .:/workspace/myproject
```

### IPv6 gotcha

The Python launcher explicitly connects to `127.0.0.1` (not `localhost`).
On systems where `/etc/hosts` resolves `localhost` to `::1` first, connecting
via the hostname would fail because debugpy binds only to IPv4.

### Path mappings (Python)

When the workspace is mounted at a different path inside the container, debugpy
cannot resolve source file locations on its own. The `path_mappings` field in
`.nvim-dap.lua` translates container paths back to host paths:

```lua
path_mappings = {
  {
    localRoot  = "/home/user/myproject",   -- where nvim opens files on the host
    remoteRoot = "/workspace/myproject",   -- where bazel executes in the container
  },
},
```

Without this, breakpoints will not resolve and the debugger will step through
files that Neovim cannot open.

### Bazel cache with gdb (C++ / Rust)

The `bazel_cache` field is passed to gdb as `set debug-file-directory`. When
building inside a container, set it to the **host-side** path of the Bazel
output base so that gdb can find `.dwo`/`.debug` files (important for split
DWARF builds):

```lua
cpp = {
  bazel_cache = vim.fn.expand("~/.cache/dev/bazel"),
},
```

If you use a Docker volume for the Bazel cache, mount it at the same path on
the host, or set `bazel_cache` to the container-internal path and accept that
`ignoreFailures = true` on that setup command.

---

## Keymaps

### Debug session (nvim-dap core)

| Key | Action |
|---|---|
| `<M-c>` | Continue / Start |
| `<M-n>` | Step over |
| `<M-s>` | Step into |
| `<M-o>` | Step out |
| `<M-b>` | Toggle breakpoint |
| `<M-B>` | Conditional breakpoint |
| `<M-t>` | Terminate session |
| `<M-r>` | Toggle REPL |
| `<M-w>` | Add watch (variable under cursor) |
| `<M-f>` | Jump to the current frame |
| `<M-p>` | Pause / interrupt |
| `<leader>gv` / `<leader>gV` | Open / close DAP view |

### Bazel launchers

| Key | Action |
|---|---|
| `<leader>gc` | C++ — Telescope picker (`cc_binary`, `cc_test`) |
| `<leader>gp` | Python — Telescope picker (`py_binary`, `py_test`) |
| `<leader>gP` | Python — manual target input |
| `<leader>gr` | Rust — Telescope picker (`rust_binary`, `rust_test`) |
| `<leader>gR` | Rust — manual target input |
| `<leader>gl` | Re-launch last used target (any language, incl. remote) |
| `<leader>gs` | Attach to the predefined dual gdbservers (`:1234`, `:1235`) |
| `<leader>gd` | C++ — [deploy & debug on a remote host over SSH](#remote-deployment-over-ssh) |
| `:DapRemoteDebug [cpp\|rust]` | Same as `<leader>gd`; only entry point for the Rust remote flow |

### Telescope DAP extensions

| Key | Action |
|---|---|
| `<leader>dfc` | DAP commands |
| `<leader>dfb` | List breakpoints |
| `<leader>dfv` | Variables |
| `<leader>dff` | Frames |

### Bazel picker (build / run / test)

| Key | Action |
|---|---|
| `<leader>bb` | Pick target & build |
| `<leader>bt` | Pick target & test |
| `<leader>br` | Pick target & run |
| `<leader>bd` | Pick target & debug (debugpy, port 5678) |
| `<leader>ba` | Toggle auto-rebuild on save |
| `<leader>bh` | Show recent targets |
| `<leader>bc` | Clear recent targets |

Inside the recent-targets picker:

| Key | Action |
|---|---|
| `<CR>` | Re-run in terminal |
| `<C-o>` | Open output buffer |
| `<C-l>` | Open Bazel log file |

---

## Debugging workflow

### C++ target in devcontainer

1. Ensure the container is running with port 1234 exposed.
2. Open Neovim from the project root (the same directory that is mounted into
   the container).
3. Press `<leader>gc` → Telescope shows all `cc_binary` and `cc_test` targets.
4. Select a target. The launcher:
   - Kills any existing gdbserver process.
   - Runs `docker exec -i dev bash -c "cd <cwd> && bazel run --config=gdbnf <target>"`.
   - Waits for gdbserver to report that it is listening on port 1234.
   - Attaches gdb in DAP MI mode.
5. Set breakpoints normally with `<M-b>`. Use `<M-c>` to continue.

### Python target in devcontainer

1. Ensure the container is running with port 5678 exposed.
2. Press `<leader>gp` → Telescope shows all `py_binary` and `py_test` targets.
3. Select a target. The launcher:
   - Runs `docker exec -i dev bash -c "cd <cwd> && bazel run --config=debugpy <target>"`.
   - Monitors stdout and stderr for the `"Listening on"` message from debugpy.
   - Creates a dynamic adapter `python_bazel_5678` and calls `dap.run()`.
4. debugpy pauses at the first line (`--wait-for-client`). Press `<M-c>`
   to continue to your first breakpoint.

### Re-launching

`<leader>gl` re-launches the last target (persisted across Neovim restarts in
`~/.cache/nvim/nvim-dap-bazel/last_target.json`) without opening the picker.
Useful when iterating on a single test.

---

## Auto-hover

While a debug session is active, resting the cursor on a variable for
`updatetime` ms (default 500 ms during a session) evaluates the expression
and shows the result in a small floating window. The window dismisses on any
cursor movement.

---

## Testing

`tests/` holds a [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
busted-style unit test suite (`plenary.nvim` is already a lazy.nvim
dependency of this config — see `plugins/telescope.lua`). Run it with:

```sh
bash lua/dap_modules/tests/run_tests.sh
```

from the nvim config root (`dotfiles/nvim`). It launches a headless Neovim
with a minimal runtimepath (this config's `lua/` plus plenary, nvim-dap,
nvim-dap-view, and telescope from `~/.local/share/nvim/lazy`) and exits
non-zero if any test fails, so it's safe to wire into a pre-commit hook or CI.

| File | Covers |
|---|---|
| `project_spec.lua` | `.nvim-dap.lua` default shape and merge behavior |
| `bazel_spec.lua` | `build_command()`, `gdb_setup_commands()`, last-target persistence, the `start_job()` ready-pattern watcher |
| `remote_spec.lua` | Every pure SSH/rsync/bazel command builder in `remote.lua`, `adapter_type_for()`, `pick_host()`, and the `deploy_and_debug()` config guard |
| `config_spec.lua` | `M.setup()`'s resulting adapters, configurations, signs, user commands, and listener wiring |
| `trace_spec.lua` | The GDB CLI output parsers (`parse_int`, `parse_frame_func`, `tfind_exhausted`) and the shared "no active session" guard clause |
| `ui_spec.lua` | The lazy.nvim plugin specs `ui.lua` returns (winbar layout, Telescope keymaps) |
| `bazel_picker_spec.lua` | `lua/bazel_picker.lua`'s recent-targets bookkeeping and auto-rebuild autocmd toggle |

**What's deliberately not covered**: the Telescope-driven pickers
(`pick_targets`/`launch_test`/`launch_python`/`launch_rust`,
`bazel_picker`'s `get_bazel_targets`/`execute_recent_targets`) and the parts
of the remote pipeline that need a real `bazel`/`ssh`/`rsync`/`docker` and a
reachable target (`locate_artifact`/`deploy`/`start_gdbserver` end to end,
and the local `start_cpp`/`start_python`/`start_rust` launchers). Those are
integration surfaces that assume a real Bazel workspace, container, or board.
Exercise them by hand — either against your own project, or against
`examples/reference-project/` (see
[Reference Bazel project](#reference-bazel-project) below) — see also
[Debugging workflow](#debugging-workflow) and
[Remote deployment over SSH](#remote-deployment-over-ssh).

`remote.lua`'s SSH/rsync/bazel command construction is deliberately split
into small pure functions (`bazel_build_cmd`, `mkdir_cmd`, `rsync_cmd`,
`gdbserver_ssh_cmd`, `adapter_type_for`, ...) specifically so these can be
asserted on directly instead of mocking `jobstart`/subprocess execution. When
extending the remote pipeline, prefer adding another such pure builder over
inlining command construction into the orchestration functions
(`locate_artifact`/`deploy`/`start_gdbserver`) — it keeps the same tests
possible.

### Coverage

```sh
bash lua/dap_modules/tests/generate_coverage.sh
```

writes a self-contained HTML line-coverage report to
`lua/dap_modules/coverage/index.html` (gitignored — see
`dap_modules/.gitignore`), covering `dap_modules/*.lua` and
`bazel_picker.lua`. There's no `luarocks`/`luacov` available in this
Nix-managed setup, so `tests/coverage.lua` is a small, dependency-free
reimplementation of the same idea: a `debug.sethook("l", ...)` line tracker.

If this config is deployed from the `dotfiles_nix` flake (see the repo's own
top-level README), the same report is also built hermetically — no
lazy.nvim install or network access needed — as `checks.x86_64-linux.dap-modules-coverage`:

```sh
nix build .#checks.x86_64-linux.dap-modules-coverage -o out/dap-modules-coverage
# -> out/dap-modules-coverage/index.html
```

This runs on every `nix flake check` (the repo's CI and local test gate —
see the flake's own comments), using `pkgs.vimPlugins.{plenary,nvim-dap,
nvim-dap-view,telescope,telescope-dap}-nvim` in place of a `~/.local/share/
nvim/lazy` install. `minimal_init.lua` picks these up via
`DAP_MODULES_TEST_PLUGIN_PATHS` (colon-separated absolute paths) when set —
falling back to the lazy.nvim directory otherwise, so `run_tests.sh`/
`generate_coverage.sh` still work unchanged against a real, already-used
Neovim config. The check fails the build (and so `nix flake check`) if any
test fails, same as the two `compiler-explorer-*` checks it sits next to in
`flake.nix`.

Plenary runs each spec file in its own nvim subprocess (see
`plenary/test_harness.lua`'s `test_directory`), so a single in-process hit
table can't see across files — each process saves its own hits to a
PID-named `*.cov.lua` file under a temp directory (via
`DAP_MODULES_COVERAGE_DIR`, set only by `generate_coverage.sh`, never by
`run_tests.sh`), which `render_coverage.lua` then merges and renders.

This is separate from `run_tests.sh` on purpose: `debug.sethook` plus
`jit.off()` (needed so LuaJIT's trace compiler doesn't skip hook calls and
undercount coverage) noticeably slows the suite down — fine for an
occasional report, not worth paying on every run. Comments, blank lines, and
bare structural keywords (`end`, `else`, ...) are reported as "n/a" rather
than "uncovered", since Lua line hooks don't fire for them at all; expect
occasional false negatives on `local function foo()` header lines too, for
the same reason (a known quirk shared with real `luacov`) — treat the
percentage as a strong signal, not a perfectly precise one.

As with the test suite itself, the Telescope pickers and real
`bazel`/`ssh`/`rsync`/`docker`-invoking code paths will always show low or
zero coverage here — that's expected, not a gap to chase.

---

## Troubleshooting

**"No targets found" in Telescope picker**

The target query runs `bazel query 'kind(cc_binary, //...)' --keep_going`.
Make sure Bazel can parse your workspace from `cwd`. If using a container,
verify `container_name` matches the running container's name exactly
(`docker ps --format '{{.Names}}'`).

**ECONNREFUSED on Python attach**

Check that the container port is published to the host (`docker ps` shows
`0.0.0.0:5678->5678/tcp`). The launcher uses `127.0.0.1` explicitly to avoid
IPv6 resolution issues.

**Breakpoints don't resolve in Python**

Add `path_mappings` to `.nvim-dap.lua` mapping the container workspace path to
the host path where Neovim has the files open.

**gdb pretty-printers not loading for Rust**

Rust uses the same gdb adapter as C++. Load the Rust pretty-printers globally
in `~/.gdbinit`:

```
python
import sys
sys.path.insert(0, '/path/to/rust/src/etc')
import gdb_lookup
gdb_lookup.register_printers(gdb.current_progspace())
end
```

**Timeout waiting for port**

The port-polling timeout is 10 000 ms. For slow Bazel builds (especially cold
builds inside a container), this may expire before gdbserver/debugpy is ready.
Increase `timeout_ms` in the `wait_for_port` call in `bazel.lua:82`.

**`[Remote] Could not resolve build artifact for <target>`**

`bazel cquery --output=starlark --starlark:expr=...` returned no usable line.
Run the same `bazel cquery` command shown in the notification by hand — a
common cause is `--config=<remote.bazel_config>` not existing in `.bazelrc`,
or the target producing more than one output file (the picker only takes
`files.to_list()[0]`).

**`Remote` gdb can't read the binary / wrong architecture**

The local `gdb_bin` doesn't understand the target's ELF machine type. Install
a multiarch or cross gdb (`gdb-multiarch` on Debian/Ubuntu, or a toolchain-
specific `<triple>-gdb`) and point `remote.gdb_bin` at it.

**Remote session won't start a second time / "Address already in use"**

A previous session didn't clean up (e.g. Neovim crashed). `M.start_gdbserver`
already runs a defensive `pkill -f <binary>` on the target before starting a
new one, but a stale *local* SSH tunnel from a crashed nvim can still hold the
local port — check `lsof -i :<port>` on the dev machine and kill it if so.

**rsync fails with "command not found" on the target**

Some minimal embedded images don't ship `rsync`. Either add it to the target
image, or replace the `rsync` invocation in `remote.lua`'s `M.deploy()` with
plain `scp -r` (loses delta-transfer and symlink dereferencing — you'd then
need to dereference the runfiles tree before copying, e.g. `tar -h -cf -
... | ssh host 'tar -xf - -C workdir'`).
