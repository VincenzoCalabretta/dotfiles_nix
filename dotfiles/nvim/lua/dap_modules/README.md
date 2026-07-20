# nvim-dap Bazel Integration

Modular DAP (Debug Adapter Protocol) configuration for Neovim that debugs Bazel
targets in C++, Python, and Rust — with first-class support for running the
build inside a **devcontainer** (Docker).

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
    └── ui.lua               ← lazy.nvim specs for nvim-dap-view + telescope-dap
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

## Per-project configuration: `.nvim-dap.lua`

Create a `.nvim-dap.lua` file at the **root of each repository**. The file is
executed with `dofile()` and must return a table. Any key you omit falls back to
the defaults shown below.

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
  },
}
```

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
| `<leader>dc` | Continue / Start |
| `<leader>dn` | Step over |
| `<leader>di` | Step into |
| `<leader>do` | Step out |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dT` | Terminate session |
| `<leader>dr` | Toggle REPL |
| `<leader>da` | Add watch (variable under cursor) |
| `<leader>dv` | Open DAP view |
| `<leader>dV` | Close DAP view |

### Bazel launchers

| Key | Action |
|---|---|
| `<leader>dt` | C++ — Telescope picker (`cc_binary`, `cc_test`) |
| `<leader>dp` | Python — Telescope picker (`py_binary`, `py_test`) |
| `<leader>du` | Rust — Telescope picker (`rust_binary`, `rust_test`) |
| `<leader>dU` | Rust — Manual target input |
| `<leader>dP` | Python — Manual target input |
| `<leader>dl` | Re-launch last used target (any language) |

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
3. Press `<leader>dt` → Telescope shows all `cc_binary` and `cc_test` targets.
4. Select a target. The launcher:
   - Kills any existing gdbserver process.
   - Runs `docker exec -i dev bash -c "cd <cwd> && bazel run --config=gdbnf <target>"`.
   - Polls `127.0.0.1:1234` every 100 ms until the port is open.
   - Attaches gdb in DAP MI mode.
5. Set breakpoints normally with `<leader>db`. Use `<leader>dc` to continue.

### Python target in devcontainer

1. Ensure the container is running with port 5678 exposed.
2. Press `<leader>dp` → Telescope shows all `py_binary` and `py_test` targets.
3. Select a target. The launcher:
   - Runs `docker exec -i dev bash -c "cd <cwd> && bazel run --config=debugpy <target>"`.
   - Monitors stdout and stderr for the `"Listening on"` message from debugpy.
   - Creates a dynamic adapter `python_bazel_5678` and calls `dap.run()`.
4. debugpy pauses at the first line (`--wait-for-client`). Press `<leader>dc`
   to continue to your first breakpoint.

### Re-launching

`<leader>dl` re-launches the last target (persisted across Neovim restarts in
`~/.cache/nvim/nvim-dap-bazel/last_target.json`) without opening the picker.
Useful when iterating on a single test.

---

## Auto-hover

While a debug session is active, resting the cursor on a variable for
`updatetime` ms (default 500 ms during a session) evaluates the expression
and shows the result in a small floating window. The window dismisses on any
cursor movement.

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
