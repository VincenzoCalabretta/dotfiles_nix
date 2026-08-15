# dotfiles_nix

A generic, reusable NixOS/Home Manager module library: terminal, shell, and
editor configuration, plus a handful of small opt-in NixOS building blocks
(WireGuard, a Forgejo Actions runner, hybrid-GPU NVIDIA support, packet
capture policy). No personal packages, no private flake inputs, no baked-in
username, home directory, or host identity.

This repo does not itself deploy anything. It exists to be imported: a
consuming flake defines its own hosts and its own Home Manager profile,
pulling in whichever pieces of this library it wants — see
`home.nix.example` and `configuration.nix.example`. My own personal
deployment (real hosts, private local-AI stack, personal packages) lives in
a separate private overlay repo that imports this one; see "Design" below
for why the split exists.

## What the flake exports

| Output | Purpose |
|---|---|
| `homeManagerModules.base` | Generic Home Manager profile: tmux, Neovim, zsh, bash, `lf`, i3, ghostty, Rust. No personal packages, private inputs, or username/homeDirectory. |
| `homeConfigurations.example` | `homeManagerModules.base` alone, under a placeholder identity — proves it evaluates and activates with zero private inputs reachable. |
| `nixosModules.nixos-base` | Shared NixOS baseline (unfree packages, flakes enabled, zsh, OpenSSH). |
| `nixosModules.wireguard` | Opt-in `wg-quick` interface module with out-of-store config files. |
| `nixosModules.forgejo-runner` | Opt-in host-executed Forgejo Actions runner. |
| `nixosModules.nvidia` | Opt-in hybrid Intel/NVIDIA PRIME-offload configuration. |
| `nixosModules.wireshark` | Opt-in passwordless packet capture for one user. |
| `nixosModules.netdebug` | Opt-in scoped passwordless `tcpdump` for one user. |
| `packages.x86_64-linux.deploy-host` | Build, switch, activate Home Manager, and set the shell for *any* flake passed via `--flake` |
| `packages.x86_64-linux.capture-host` | Snapshot live `/etc/nixos` state into a host directory |
| `packages.x86_64-linux.set-default-shell` | Set the login shell to zsh |
| `checks.x86_64-linux.*` | Home Manager base-profile build, deployment tools, and a NixOS VM test of the shared modules |

The flake is x86_64-Linux-specific. `deploy-host` and `capture-host` are
generic — they take `--flake <path>` — so a consuming flake reuses them
directly instead of redefining its own build/switch entry points.

## Design: why this repo has no hosts or private inputs

This started as one repo with everything: two real NixOS hosts, a private
local-AI stack (`opencode`/`claude` MCP wiring pulling in flake inputs from
a personal Forgejo instance), and personal packages, all under one
`homeConfigurations."v"`. That made it impossible to reuse on a machine that
must not fetch that private infrastructure — a work laptop, for instance,
with its own username and no route to a personal Forgejo.

The fix was to make this repo the generic, private-infra-free half — a
module *library*, not a deployment — and move everything personal (hosts,
private inputs, opencode/claude, personal packages) into a separate private
overlay repo that imports it via `inputs.dotfiles`. Concretely:

- `home.nix` (this repo) has no `home.username`/`home.homeDirectory` and no
  personal packages; it's exported as `homeManagerModules.base`.
- `modules/opencode.nix`, `modules/claude.nix`, `modules/pi.nix`, and
  `modules/llama-relay.nix` — all coupled to the private
  `llama-server`/`opencode-mcp-tools` flake inputs and a personal Forgejo —
  live in the overlay repo, not here.
- `modules/hardware.nix` (this laptop's own audio/USB-device quirks) also
  lives in the overlay, colocated with the one host it applies to — it was
  never a reusable module, just factored into its own file.
- The real `hosts/home`, `hosts/server` configurations, with their real
  hostnames, locale, disk UUIDs, and usernames, live in the overlay.
- `homeConfigurations.example` and `checks.home-manager-build` in *this*
  repo prove the base profile evaluates and activates standalone, with zero
  private inputs reachable — that's the actual portability guarantee, not
  just a claim in prose.

A work-machine deployment is then just another consumer of this same
library: its own flake (or another spot in the overlay repo) sets its own
`home.username`/`homeDirectory`/hostname and imports only the modules it
wants, with no path to the private inputs at all.

## Repository layout

```text
.
├── flake.nix                     # inputs, module-library outputs, generic deploy tools
├── flake.lock                    # exact nixpkgs and Home Manager pins
├── home.nix                      # generic base profile (homeManagerModules.base)
├── home.nix.example              # template for consuming homeManagerModules.base
├── configuration.nix.example     # template for consuming nixosModules.*
├── modules/
│   ├── nixos-base.nix            # shared NixOS baseline
│   ├── nvidia.nix                # hybrid-GPU PRIME offload (bus IDs are options, no default)
│   ├── wireguard.nix             # out-of-store wg-quick service definitions
│   ├── forgejo-runner.nix        # stable runner user, service and host tools
│   ├── wireshark.nix             # privileged capture policy (user is an option)
│   ├── netdebug.nix              # scoped passwordless tcpdump policy (user is an option)
│   └── {nvim,tmux,zsh,...}.nix   # Home Manager packages and deployed configs
├── dotfiles/
│   ├── nvim/                     # Lua config, DAP, LSP, pickers and GDB helpers
│   ├── tmux/                     # session/debug/navigation helpers
│   ├── zsh/, bash/                # shell, aliases and plugins
│   └── i3/, ghostty/, lf/         # desktop/terminal/file-manager configuration
├── tools/
│   ├── deploy-host.sh            # controlled live deployment sequence (generic, takes --flake)
│   ├── capture-host.sh           # portable host snapshot + secret guardrail
│   └── check-checklist-coverage.sh  # generic CHECKLIST.md marker checker
├── tests/checklist-vm.nix        # isolated NixOS integration test of the shared modules
└── .forgejo/workflows/ci.yml     # self-hosted CI: `nix flake check`
```

## Home Manager profile (`homeManagerModules.base`)

Terminal, shell, editor, file manager, window manager, and Rust modules,
with no personal packages, no private flake inputs, and no baked-in
`home.username`/`home.homeDirectory`. A consumer imports it and layers its
own identity and extras on top — see `home.nix.example`:

```nix
{ pkgs, inputs, ... }:
{
  imports = [ inputs.dotfiles.homeManagerModules.base ];
  home.username = "you";
  home.homeDirectory = "/home/you";
  home.packages = with pkgs; [ /* whatever's specific to this machine */ ];
}
```

The configuration deliberately deploys both a program and the runtime
dependencies referenced by its scripts; a tmux binding or Neovim tool should
not depend on an untracked host package.

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
scripts by name. `.xinitrc` is generated to load Home Manager's session
variables before `exec i3`, for setups that start X manually via `startx`.

Zsh and Bash are both deployed (Oh My Zsh / ble.sh respectively, syntax
highlighting, autosuggestions, vi-mode, and repository-local aliases).
Ghostty, `lf`, i3, fonts, clipboard tools, archive tools, compiler basics,
Git, and daily CLI utilities are part of the same activation closure.

## NixOS modules

| Module | What it needs from the consumer |
|---|---|
| `nixos-base` | Nothing — drop it in as-is. |
| `wireguard` | Optionally override `dotfiles.wireguard.interfaces`; config files stay outside the Nix store (default paths: `/etc/wireguard/{wg1,wg3}.conf`). |
| `forgejo-runner` | `dotfiles.forgejo-runner.url` (no default — must be set). Registration token and SSH deploy key are provisioned out of band. |
| `nvidia` | `dotfiles.nvidia.intelBusId`/`.nvidiaBusId` (no default — `lspci -nn \| grep -Ei 'vga\|3d'` on the actual machine). |
| `wireshark` | `dotfiles.wireshark.user` (no default). |
| `netdebug` | `dotfiles.netdebug.user` (no default). |

None of these hardcode a username, host identity, or secret — see
`configuration.nix.example` for how a consumer wires them up:

```nix
{ pkgs, inputs, ... }:
{
  imports = [ inputs.dotfiles.nixosModules.wireguard ];
  dotfiles.wireguard.enable = true;
  # ...
}
```

## Safe evaluation and testing

```sh
# Parse/evaluate every flake output without building closures.
nix flake check --no-build

# Build the base Home Manager profile under a placeholder identity.
nix build .#checks.x86_64-linux.home-manager-build

# Run the NixOS VM integration test for the shared modules (wireguard,
# forgejo-runner, netdebug, wireshark) — proves they produce the state their
# option docs promise, independent of any concrete host.
nix build .#checks.x86_64-linux.checklist-vm -L
```

The complete local gate is `nix flake check` — it requires no private
inputs and no network access beyond the standard Nix substituters.

## CI

Every push and pull request runs `nix flake check` on a self-hosted Forgejo
Actions runner (deployed by the private overlay repo's `home` host, via this
repo's own `nixosModules.forgejo-runner`). See `.forgejo/workflows/ci.yml`.

## Adapting / consuming the library

- **Just want the terminal/editor/shell profile?** Import
  `homeManagerModules.base` from your own flake (see `home.nix.example`).
  No fork needed.
- **Want the NixOS building blocks (WireGuard, Forgejo runner, NVIDIA
  PRIME, packet-capture policy)?** Import the relevant `nixosModules.*` from
  your own host configuration (see `configuration.nix.example`) and set
  whatever options that module requires (see the table above).
- **Want to see a complete, real deployment built this way** — hosts,
  private local-AI stack, personal packages, secrets provisioning checklist
  — that's the private overlay repo, not this one.

The `nvidia`/`wireshark`/`netdebug`/`forgejo-runner` modules intentionally
have no defaults for machine-specific values (bus IDs, usernames, URLs) —
evaluation fails loudly if you enable one without setting them, rather than
silently reusing someone else's laptop's values.

## Secret handling

No private WireGuard keys, Forgejo registration tokens, or SSH private keys
should ever be committed here — the modules in this repo are specifically
designed so that's structurally true (they only take *paths* to secrets, and
those default paths point outside the Nix store). Still, before publishing
any change, review tracked content and history:

```sh
git grep -n -I -E \
  '(BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|TOKEN=|private[_-]?key|password)'
git log --all --stat
```

## Known limitations

- Only x86_64 Linux is exported.
- `modules/hardware.nix`-style machine-specific quirks don't belong in this
  repo by design — if you're forking a module and it turns out to encode a
  specific machine's hardware, that's a sign it should live in your own
  overlay instead, colocated with the host it applies to.
- CI (in the overlay repo, which owns the runner) runs jobs directly on the
  host without container isolation.
