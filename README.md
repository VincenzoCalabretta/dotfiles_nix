# dotfiles-nix

This repository is the declarative configuration used for my daily NixOS
development environment. One flake owns the user profile, two complete NixOS
hosts, terminal/editor/shell configuration, networking, a self-hosted CI
runner, and a local LLM-assisted development stack.

The goal is not to provide a universal NixOS distribution. It is a concrete,
versioned example of how I make a development workstation reproducible: the
configuration files and every tool they invoke are deployed together, host
changes are built before they are switched, secrets remain outside the Nix
store, and the manual deployment contract is exercised by CI and a NixOS VM
test.

## Highlights

- **Single flake, two layers.** Home Manager owns the unprivileged development
  environment; NixOS modules own boot, hardware, networking, GPU, privileged
  packet capture, and services.
- **Two versioned hosts.** `home` is a graphical Intel/NVIDIA development
  laptop; `server` is a minimal headless host. Both share a small NixOS base.
- **Editor and debugger environment.** Neovim, language servers, Bazel-aware
  navigation, custom DAP modules, GDB pretty-printers, and tmux debugging
  helpers are deployed as one closure.
- **Local AI stack.** A llama.cpp inference service, CPU embedding service,
  SearXNG, OpenCode, five MCP servers, and automatic repository reindexing are
  wired with exact Nix-store paths.
- **Operational guardrails.** WireGuard keys and runner credentials stay in
  root-owned files outside the repository. Host capture refuses to persist
  WireGuard references, and every item in `CHECKLIST.md` must be classified as
  manual, CI-proven, or VM-tested.
- **Self-hosted CI.** A Forgejo Actions runner executes directly on the NixOS
  host with a warm Nix store, while the flake verifies both system closures,
  the Home Manager activation, deployment tools, checklist coverage, and the
  secret-provisioning VM scenario.

## What the flake exports

| Output | Purpose |
|---|---|
| `homeConfigurations.v` | Home Manager profile for user `v` |
| `nixosConfigurations.home` | Full graphical workstation system closure |
| `nixosConfigurations.server` | Full headless server system closure |
| `nixosModules.wireguard` | Opt-in `wg-quick` interface module with out-of-store config files |
| `nixosModules.forgejo-runner` | Opt-in host-executed Forgejo Actions runner |
| `packages.x86_64-linux.activate` | Home Manager activation package |
| `apps.x86_64-linux.{home,server}-{build,switch}` | Build-only and live-switch entry points |
| `apps.x86_64-linux.deploy-host` | Build, switch, activate Home Manager, and set the shell |
| `apps.x86_64-linux.capture-host` | Snapshot live `/etc/nixos` state into a host directory |
| `checks.x86_64-linux.*` | Host closures, Home Manager, tools, checklist coverage, and VM tests |

The flake is currently x86_64-Linux-specific. User name, home directory,
hardware identifiers, encrypted-volume UUIDs, GPU bus IDs, network addresses,
and service endpoints are personal configuration and must be reviewed before
using the repository on another machine.

## Repository layout

```text
.
├── flake.nix                     # inputs, host/profile outputs, apps and checks
├── flake.lock                    # exact nixpkgs, Home Manager and service inputs
├── home.nix                      # shared user profile and Home Manager modules
├── hosts/
│   ├── home/                     # graphical workstation configuration + hardware
│   └── server/                   # headless server configuration + hardware
├── modules/
│   ├── nixos-base.nix            # shared NixOS baseline
│   ├── hardware.nix              # laptop power/firmware/udev and nix-ld support
│   ├── nvidia.nix                # hybrid-GPU PRIME offload configuration
│   ├── wireguard.nix             # out-of-store wg-quick service definitions
│   ├── forgejo-runner.nix        # stable runner user, service and host tools
│   ├── wireshark.nix             # privileged capture policy
│   ├── netdebug.nix              # constrained passwordless tcpdump policy
│   └── {nvim,tmux,zsh,...}.nix   # Home Manager packages and deployed configs
├── dotfiles/
│   ├── nvim/                     # Lua config, DAP, LSP, pickers and GDB helpers
│   ├── tmux/                     # session/debug/navigation helpers
│   ├── zsh/                      # shell, aliases and plugins
│   ├── i3/, ghostty/, lf/        # desktop/terminal/file-manager configuration
│   └── opencode/                 # plugin and detailed local-AI documentation
├── tools/
│   ├── deploy-host.sh            # controlled live deployment sequence
│   ├── capture-host.sh           # portable host snapshot + secret guardrail
│   └── check-checklist-coverage.sh
├── tests/checklist-vm.nix        # isolated NixOS integration test
├── CHECKLIST.md                  # human deployment and secret-provisioning contract
└── .forgejo/workflows/ci.yml     # two-job self-hosted CI workflow
```

## Home Manager profile

`home.nix` imports the terminal, shell, editor, file manager, window manager,
local-AI, Claude, and Rust modules. The configuration deliberately deploys
both a program and the runtime dependencies referenced by its scripts; a tmux
binding or Neovim tool should not depend on an untracked host package.

### Neovim

The Neovim tree is Lua-based and pins its plugin graph in
`dotfiles/nvim/lazy-lock.json`. Nix supplies LSPs and native build
dependencies rather than delegating language-server installation to Mason.
Notable local code includes:

- Bazel target navigation and picker integration;
- custom DAP configuration, UI, trace, and project modules;
- GDB launch helpers and libstdc++/project pretty-printers;
- project/session persistence and Git inspection;
- a scratchpad hover workflow and numeric-conversion utilities; and
- Treesitter, completion, diagnostics, profiler, aerial, telescope, and
  diff/history integrations.

### tmux, i3, shell and terminal

The tmux configuration provides i3-like navigation, project session creation,
debug-session helpers, display toggles, and command/language cheat sheets.
`home.sessionPath` exposes the helper directory so both tmux and i3 can invoke
scripts by name. Because this machine starts X with `startx`, Home Manager also
generates `.xinitrc` to load its session variables before `exec i3`.

Zsh is deployed with Oh My Zsh, syntax highlighting, autosuggestions, vi-mode,
and repository-local aliases. Ghostty, `lf`, i3, fonts, clipboard tools, archive
tools, compiler basics, Git, and daily CLI utilities are part of the same
activation closure.

### Local LLM and MCP toolchain

`modules/opencode.nix` builds two flake inputs and embeds their exact Nix-store
paths into the generated OpenCode configuration:

- a llama.cpp OpenAI-compatible inference server at `127.0.0.1:8080/v1`;
- a CPU embedding server for semantic repository indexing;
- SearXNG-backed web search;
- code search, test runner, grammar/structured-output, and repository-index
  MCP servers; and
- a JavaScript plugin that incrementally reindexes a repository after file
  modifications.

The `opencode` wrapper starts inference and embedding systemd user services,
runs the real CLI, and stops the services only after the last concurrent
OpenCode process exits. The model is not started at login because it occupies
most of the configured laptop GPU's VRAM. SearXNG remains explicitly on-demand:

```sh
systemctl --user start opencode-searxng
opencode
```

The reindex-on-save plugin uses `setsid` plus an unreferenced child process so
an index update survives short-lived `opencode run` sessions. MCP binaries are
published to the generated configuration as Nix-store paths rather than
looked up from mutable sibling repositories.

See [`dotfiles/opencode/README.md`](dotfiles/opencode/README.md) for service,
model, MCP, and reindexing details.

## NixOS hosts and system modules

| Host | Intended role | Notable modules |
|---|---|---|
| `home` | Development laptop/workstation | i3/X11, hybrid NVIDIA PRIME, power management, WireGuard, Wireshark, network debugging, Forgejo runner |
| `server` | Headless NixOS server | shared base, OpenSSH, WireGuard, minimal package set |

Both hosts use systemd-boot and current pinned kernel packages. Their checked-in
`hardware-configuration.nix` files are machine-specific; they must never be
copied blindly to another system.

### WireGuard secret boundary

The WireGuard module owns service declarations but never imports private keys
into the Nix store. By default it expects complete, root-owned mode-0600
`wg-quick` files at:

- `/etc/wireguard/wg1.conf`, enabled at boot; and
- `/etc/wireguard/wg3.conf`, available for manual activation.

Consumers can override `dotfiles.wireguard.interfaces.<name>.configFile` and
`.autostart`. The config file must contain both `[Interface]` and `[Peer]`
sections and remain outside the repository.

### Forgejo Actions runner

The runner module creates a stable `forgejo-runner` system user rather than a
dynamic user so it can own a persistent SSH deploy key and participate in the
Nix trusted-user policy. Jobs run directly on the host, not in Docker; that
improves cache reuse but means workflow code has the privileges of the runner
account.

Registration tokens live in
`/etc/forgejo-runner/registration-token.env`, and the SSH key lives below
`/var/lib/forgejo-runner/.ssh/`. Both are provisioned out of band. The exact
order and permissions are maintained in [`CHECKLIST.md`](CHECKLIST.md).

## Publication and portability note

The checked-in flake currently fetches `llama-server` and
`opencode-mcp-tools` from a private Forgejo address. A public clone cannot
evaluate all outputs unless it can reach those inputs. Before presenting this
as a generally buildable public repository, either publish those dependencies,
replace their URLs with public mirrors, or make the AI module/inputs optional.

Likewise, the repository is configured for user `v` at `/home/v`. Forks should
parameterize or update `home.username`, `home.homeDirectory`, host users,
hardware files, GPU identifiers, WireGuard interfaces, Forgejo endpoints, and
the selected local model before activation.

## Safe evaluation and testing

The following commands do not switch the running system:

```sh
# Parse/evaluate every flake output without building closures.
nix flake check --no-build

# Build the Home Manager activation closure.
nix build .#checks.x86_64-linux.home-manager-build

# Build both complete NixOS system closures.
nix build .#nixosConfigurations.home.config.system.build.toplevel
nix build .#nixosConfigurations.server.config.system.build.toplevel

# Prove every checklist item is classified.
nix build .#checks.x86_64-linux.checklist-coverage -L

# Run the NixOS VM integration test for automatable deployment/secret steps.
nix build .#checks.x86_64-linux.checklist-vm -L
```

The complete local gate is:

```sh
nix flake check
```

It builds the Home Manager activation, both NixOS systems, deployment tools,
checklist coverage checker, and VM test. Expect a substantial first build.
Evaluation requires all locked inputs—including the private local-AI inputs—to
be reachable or already present in the Nix store.

## CI

Every push and pull request runs two Forgejo jobs on the self-hosted runner:

| Job | Checks |
|---|---|
| `checks` | `nix flake check`, explicit Home Manager build, checklist classification, and checklist VM test |
| `system-builds` | full `home` and `server` closures plus smoke builds of both build-only apps |

The CI host executes jobs directly and has a warm Nix store. A local
`nix flake check` exercises the same flake checks, while the workflow keeps
system builds as a separately visible job with a longer timeout.

## Installing the profile on a new machine

This section describes the existing personal deployment. Read
[`CHECKLIST.md`](CHECKLIST.md) before changing a live machine.

Prerequisites:

- NixOS with `nix-command` and `flakes` enabled;
- a checkout whose private flake inputs are reachable;
- reviewed, machine-correct host and hardware configuration; and
- secrets provisioned outside the checkout.

First Home Manager activation:

```sh
git clone <repository-url> ~/dotfiles-nix
cd ~/dotfiles-nix

# Rename any conflicting unmanaged file to *.backup before linking the
# declarative version.
nix run github:nix-community/home-manager -- \
  switch -b backup --flake .#v
```

Subsequent user-profile updates:

```sh
home-manager switch --flake ~/dotfiles-nix#v
```

Home Manager copies `dotfiles/**` through the Nix store. An edit becomes live
only after another activation. The exception is an intentionally configured
out-of-store symlink, which this repository does not use by default.

## Building and deploying a host

Build first without mutating the live system:

```sh
nix run ~/dotfiles-nix#home-build
nix run ~/dotfiles-nix#server-build
```

The complete deployment tool then:

1. builds `nixosConfigurations.<host>`;
2. runs `sudo nixos-rebuild switch`;
3. activates the Home Manager package; and
4. selects zsh as the login shell if needed.

```sh
nix run ~/dotfiles-nix#deploy-host -- --host home
nix run ~/dotfiles-nix#deploy-host -- --host server
```

Optional flags are `--skip-build`, `--skip-home`, and `--no-shell`. Skipping
the build removes the pre-switch safety gate and should be reserved for a
closure already built and reviewed in the same state.

System-only entry points are also available:

```sh
nix run ~/dotfiles-nix#home-switch
nix run ~/dotfiles-nix#server-switch
```

These commands invoke `sudo` and change the live operating system. Do not run
them merely to test a public clone.

## Capturing live host state

`capture-host` copies the live NixOS configuration into `hosts/<name>/`,
rewrites known absolute checkout imports to repository-relative paths, records
the active generation, and evaluates the resulting host output:

```sh
nix run ~/dotfiles-nix#capture-host
nix run ~/dotfiles-nix#capture-host -- --host server
nix run ~/dotfiles-nix#capture-host -- --generate-hardware
nix run ~/dotfiles-nix#capture-host -- --full-build
```

It intentionally ignores comments while rewriting the live configuration and
refuses to leave captured files behind if they reference `/etc/wireguard/`.
The tool cannot determine whether arbitrary unrelated literals are secrets, so
the generated diff still requires human review:

```sh
git diff --stat
git diff -- hosts/<host>
```

Only regenerate hardware configuration after a hardware, disk, partition, or
boot-layout change.

## Rollback

NixOS keeps previous generations. For a problem discovered immediately after
a live switch:

```sh
sudo nixos-rebuild switch --rollback
```

If a generation prevents boot, select an earlier generation in systemd-boot,
then make the rollback persistent and correct the checked-in configuration
before attempting another switch. Home Manager generations can be inspected
and rolled back independently with `home-manager generations`.

## Adapting the repository

At minimum, a fork should review:

1. `home.nix`: user name, home directory, package policy and imported modules;
2. `hosts/*/configuration.nix`: host name, locale, users, boot, filesystems,
   graphical stack and enabled opt-in modules;
3. `hosts/*/hardware-configuration.nix`: regenerate on the actual target;
4. `modules/nvidia.nix` and `modules/hardware.nix`: laptop/GPU-specific IDs
   and udev/power policy;
5. `modules/wireguard.nix`: desired interfaces and out-of-store file paths;
6. `modules/forgejo-runner.nix`: URL, labels, capacity and certificate policy;
7. `modules/opencode.nix`: public input sources, model, GPU/VRAM assumptions,
   endpoint, context limits and tool permissions; and
8. `flake.nix`: supported systems, input URLs, profile name and exposed hosts.

The OpenCode configuration currently sets its tool permission policy to
`allow` for a trusted single-user machine. That is a material security choice;
do not copy it unchanged to a shared workstation or untrusted automation host.

## Secret handling

No private WireGuard keys, Forgejo registration tokens, or SSH private keys
should be committed. Before publication, review tracked content and history in
addition to relying on `.gitignore`:

```sh
git grep -n -I -E \
  '(BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|TOKEN=|private[_-]?key|password)'
git log --all --stat
```

Hardware UUIDs, host names, local IPs, and public keys are not authentication
secrets, but they are still personal infrastructure metadata and should be
published intentionally.

## Known limitations

- Only x86_64 Linux is exported.
- The profile and host definitions are hard-coded for one user and two
  machines rather than parameterized as a reusable library.
- Two flake inputs and the Forgejo runner default to private infrastructure.
- The desktop configuration assumes X11/i3 started through `startx`, hybrid
  NVIDIA hardware, and specific encrypted-disk layout.
- CI runs jobs directly on the host without container isolation.
- The local AI configuration assumes a particular 8 GB NVIDIA GPU budget and
  grants OpenCode broad local tool permissions.
- The repository has no top-level license file yet; add one before public
  release.
