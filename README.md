# dotfiles_nix

A generic, reusable NixOS/Home Manager module library: terminal, shell, and
editor configuration, plus opt-in NixOS building blocks (WireGuard, a
Forgejo Actions runner, hybrid-GPU NVIDIA support, packet capture policy).
No personal packages, private flake inputs, or baked-in username/host
identity.

This repo does not deploy anything itself — it's imported by a consuming
flake that defines its own hosts and Home Manager profile (see
`home.nix.example` / `configuration.nix.example`). My own real deployment
(hosts, private local-AI stack, personal packages) lives in a separate
private overlay repo that imports this one, so this half stays usable on
machines (e.g. a work laptop) that must not reach that private
infrastructure.

## What the flake exports

| Output | Purpose |
|---|---|
| `homeManagerModules.base` | Generic Home Manager profile: tmux, Neovim, zsh, bash, `lf`, i3, ghostty, Rust. |
| `homeConfigurations.example` | `base` under a placeholder identity — proves it activates with zero private inputs reachable. |
| `nixosModules.nixos-base` | Shared NixOS baseline (unfree packages, flakes enabled, zsh, OpenSSH). |
| `nixosModules.wireguard` | Opt-in `wg-quick` interfaces, config files outside the Nix store. |
| `nixosModules.forgejo-runner` | Opt-in host-executed Forgejo Actions runner. |
| `nixosModules.nvidia` | Opt-in hybrid Intel/NVIDIA PRIME-offload configuration. |
| `nixosModules.wireshark` | Opt-in passwordless packet capture for one user. |
| `nixosModules.netdebug` | Opt-in scoped passwordless `tcpdump` for one user. |
| `nixosModules.compiler-explorer` | Opt-in self-hosted Compiler Explorer service. |
| `packages.deploy-host` | Build, switch, and activate Home Manager for any flake via `--flake`. |
| `packages.capture-host` | Snapshot live `/etc/nixos` state into a host directory. |
| `packages.set-default-shell` | Set the login shell to zsh. |
| `checks.*` | Home Manager build, deployment tools, and NixOS/Neovim tests — see [Testing](#testing). |

x86_64-Linux only. `deploy-host`/`capture-host` take `--flake <path>`, so a
consumer reuses them instead of redefining its own build/switch tooling.

## Repository layout

```text
.
├── flake.nix                  # inputs, module-library outputs, deploy tools
├── home.nix                   # generic base profile (homeManagerModules.base)
├── home.nix.example           # template for consuming homeManagerModules.base
├── configuration.nix.example  # template for consuming nixosModules.*
├── modules/                   # one file per NixOS/Home Manager module
├── dotfiles/
│   ├── nvim/                  # Lua config, DAP, LSP, pickers, GDB helpers
│   ├── tmux/, zsh/, bash/     # shell and multiplexer config
│   └── i3/, ghostty/, lf/     # desktop/terminal/file-manager config
├── tools/                     # deploy-host.sh, capture-host.sh
├── tests/                     # NixOS VM and Neovim plugin tests
└── .forgejo/workflows/ci.yml  # self-hosted CI: `nix flake check`
```

## Consuming it

Import `homeManagerModules.base` and layer your own identity on top:

```nix
{ pkgs, inputs, ... }:
{
  imports = [ inputs.dotfiles.homeManagerModules.base ];
  home.username = "you";
  home.homeDirectory = "/home/you";
  home.packages = with pkgs; [ /* machine-specific extras */ ];
}
```

NixOS modules work the same way — import the one you want and set its
options (see `configuration.nix.example`):

| Module | Required option |
|---|---|
| `nixos-base` | none |
| `wireguard` | none (override `dotfiles.wireguard.interfaces` if needed) |
| `forgejo-runner` | `dotfiles.forgejo-runner.url` |
| `nvidia` | `dotfiles.nvidia.intelBusId` / `.nvidiaBusId` |
| `wireshark` | `dotfiles.wireshark.user` |
| `netdebug` | `dotfiles.netdebug.user` |
| `compiler-explorer` | none |

These intentionally have no defaults for machine-specific values — a
missing option fails evaluation loudly instead of reusing someone else's
laptop's values.

### Neovim highlights

Lua-based, plugins pinned in `dotfiles/nvim/lazy-lock.json`; Nix supplies
LSPs and native build deps instead of Mason where practical. Notable
pieces:

- Bazel target picker plus a `starpls` Starlark LSP for BUILD/`*.bzl` files
  (`K` shows the built-in Bazel docs, same as any other LSP hover).
- Custom DAP config covering local, devcontainer, and remote (cross-compile
  → rsync → `gdbserver` over SSH → attach) debugging — see
  `dotfiles/nvim/lua/dap_modules/README.md`.
- GDB launch helpers with libstdc++ pretty-printers.
- An opt-in Compiler Explorer client (`dotfiles.nvim.compilerExplorer.enable
  = true`): press `<leader>ce` on a C/C++/Rust buffer to compile the current
  file (or selection) against a local, socket-activated Compiler Explorer
  service and view the generated assembly; `K` in an assembly buffer gives
  architecture-aware instruction/register help. Run `:help
  compiler-explorer-commands` for the full command reference.
- Project/session persistence, Git inspection, Treesitter, completion,
  diagnostics, and Telescope integrations.

Lazy.nvim's update checker is off, so a `lazy-lock.json` bump doesn't
reach an existing checkout on its own — run `:Lazy restore` after
activating a new generation to pick it up.

## Deploying

First activation on a machine without Home Manager installed yet:

```sh
nix run github:nix-community/home-manager -- switch -b backup --flake '.#<name>'
```

`-b backup` renames any pre-existing plain file Home Manager would
otherwise refuse to overwrite; only matters on this first run.

Once the consuming flake defines its own `packages.<system>.activate`:

```sh
nix run '.#activate'
```

For a full NixOS + Home Manager host, use this flake's `deploy-host`
(builds, switches, activates Home Manager, sets the default shell):

```sh
nix run 'github:<your-fork>#deploy-host' -- --flake '.' --host '<hostname>'
```

`--skip-build`, `--skip-home`, and `--no-shell` each omit one step — see
`tools/deploy-host.sh`.

## Testing

```sh
nix flake check                                              # everything
nix build .#checks.x86_64-linux.home-manager-build            # base profile builds
nix build .#checks.x86_64-linux.checklist-vm -L                # NixOS module VM test
nix build .#checks.x86_64-linux.dap-modules-coverage           # nvim DAP unit tests + coverage
```

Add `-o out/<name>` to keep result symlinks in the gitignored `out/`
directory instead of cluttering the repo root. `nix flake check` needs no
private inputs and no network beyond the standard Nix substituters. CI runs
it on every push/PR via a self-hosted Forgejo runner (`.forgejo/workflows/ci.yml`).

## Secret handling

Modules here only ever take *paths* to secrets, with defaults pointing
outside the Nix store — no key material should ever be committed. Before
publishing a change, double-check anyway:

```sh
git grep -n -I -E '(BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|TOKEN=|private[_-]?key|password)'
```

## Known limitations

- x86_64 Linux only.
- Machine-specific quirks (`modules/hardware.nix`-style) belong in your own
  overlay, colocated with the host they apply to — not here.
