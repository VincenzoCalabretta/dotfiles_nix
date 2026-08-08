# dotfiles-nix

Home-manager flake for tmux, neovim, zsh (oh-my-zsh), lf, i3.
Configs are shipped verbatim from `dotfiles/**` — no rewrite into Nix.
Modules provide every runtime dependency the configs reference.

## Layout

```
flake.nix          # inputs: nixpkgs (unstable) + home-manager
home.nix           # shared packages, programs.direnv, sessionPath, module imports
hosts/
  home/              # desktop (nvidia, i3, WireGuard, forgejo-runner, laptop hardware)
    configuration.nix
    hardware-configuration.nix
  server/            # headless (WireGuard, minimal)
    configuration.nix
    hardware-configuration.nix
modules/
  tmux.nix         # tmux + python3 + xrandr           → ~/.config/tmux
  nvim.nix         # neovim + LSPs + build deps        → ~/.config/nvim
  zsh.nix          # zsh + oh-my-zsh + plugins         → ~/.zshrc, ~/.config/zsh
  lf.nix           # lf + archive tools + mimeopen     → ~/.config/lf
  i3.nix           # dmenu, i3status, rofi…            → ~/.config/i3
  ghostty.nix      # ghostty terminal                   → ~/.config/ghostty
  opencode.nix     # opencode + local LLM + MCP tools    → ~/.config/opencode
  wireguard.nix    # opt-in NixOS WireGuard deployment  → wg-quick service
  forgejo-runner.nix # opt-in Forgejo Actions runner     → gitea-runner service
  nixos-base.nix   # shared NixOS baseline (zsh, openssh, flakes, allowUnfree)
  hardware.nix     # laptop-specific TLP / thermald / firmware
  nvidia.nix       # NVIDIA driver + prime-offload
  wireshark.nix    # NOPASSWD tcpdump for packet capture
  netdebug.nix     # tcpdump sudo rule for Ethernet bring-up debugging
tools/
  deploy-host.sh   # single-stop deploy: nixos-rebuild switch + home-manager + shell
  capture-host.sh  # snapshot live /etc/nixos/* into hosts/<name>/ with portable imports
dotfiles/          # verbatim source configs (tmux/ nvim/ zsh/ lf/ i3/ ghostty/ opencode/)
.forgejo/
  workflows/ci.yml # Forgejo Actions CI (runs on self-hosted runner)
```

OpenCode is configured for a local llama.cpp server plus MCP tools (web
search, structural code search, a test/build feedback loop, structured
output) - both built from flake inputs fetched from Forgejo
(`10.10.0.101`), not a manual sibling checkout. `home-manager switch` alone
is enough to deploy it; start the services with
`systemctl --user start llama-server opencode-searxng`, then run `opencode`.
See [`dotfiles/opencode/README.md`](dotfiles/opencode/README.md) for details.

`home.sessionPath` prepends `~/.config/tmux/scripts` so helpers
(`tmux-sessionizer`, `randr_toggle_displays.py`, `tmux-cht.sh`, …) resolve
by bare name from tmux/i3 bindings.

## Activate on a new machine

Prerequisites: NixOS with flakes enabled (`nix.settings.experimental-features = [ "nix-command" "flakes" ];`)
and, if you use i3, `services.xserver.windowManager.i3.enable = true;` in
`/etc/nixos/configuration.nix` — home-manager cannot enable a WM.

```sh
git clone ssh://git@10.10.0.101/v/dotfiles_nix.git ~/dotfiles-nix
cd ~/dotfiles-nix

# First activation. -b backup renames any pre-existing conflicting file
# (~/.zshrc, ~/.config/{nvim,tmux,i3,lf,zsh}, …) to <name>.backup before
# symlinking. Drop -b backup on a truly empty $HOME.
nix run github:nix-community/home-manager -- switch -b backup --flake .#v
```

The first switch also sets your login shell to zsh via a `home.activation`
hook (requires zsh in `/etc/shells`; add `environment.shells = [ pkgs.zsh ];`
to your NixOS config if `chsh` refuses). `nix run .#set-default-shell` does
the same manually.
```

Later rebuilds (home-manager is on PATH after the first activation):

```sh
home-manager switch --flake ~/dotfiles-nix#v
```

## NixOS host configuration

There are two versioned host configurations under `hosts/`:

| Host     | Profile  | Key modules                         |
|----------|----------|-------------------------------------|
| `home`   | Desktop  | nvidia, i3, WireGuard, wireshark, laptop hardware |
| `server` | Headless | WireGuard (minimal, no display)     |

Both share a common base via `modules/nixos-base.nix` (zsh, openssh, flakes,
allowUnfree). Machine-specific settings live in the host's own
`configuration.nix` and `hardware-configuration.nix`. See
[`hosts/home/README.md`](hosts/home/README.md) for the complete desktop
deployment procedure, and [`hosts/server/README.md`](hosts/server/README.md)
for the server.

Deployment is intentionally explicit; evaluating or updating this checkout
does not change the running system. Use `deploy-host` for a single-stop
deploy that runs the NixOS switch, home-manager activation, and default-shell
setup in one invocation:

```sh
# Desktop: build + switch + home-manager + shell.
nix run ~/dotfiles-nix#deploy-host -- --host home

# Server: same, but for the headless host.
nix run ~/dotfiles-nix#deploy-host -- --host server
```

The individual steps remain available for manual use:

```sh
# Desktop: build without activating.
nix run ~/dotfiles-nix#home-build

# Desktop: build and activate (requires sudo).
nix run ~/dotfiles-nix#home-switch

# Server: build without activating.
nix run ~/dotfiles-nix#server-build

# Server: deploy locally or via SSH.
nix run ~/dotfiles-nix#server-switch
```

Before the first switch on a machine, compare `hosts/<name>/` with the live
`/etc/nixos/` configuration and commit the desired state. Use `capture-host`
to snapshot the live system config into the repo automatically:

```sh
nix run ~/dotfiles-nix#capture-host
```

Regenerate the hardware file only after hardware or partition-layout changes,
then review and commit its diff. WireGuard private keys remain outside the
repository in `/etc/wireguard/`.

## WireGuard deployment

WireGuard is deployed by NixOS, rather than home-manager, because bringing up
an interface requires system privileges. The flake exports an opt-in module;
it starts `wg-quick-wg1.service` at boot and reconciles both interfaces whenever
you run `nixos-rebuild switch`.

The default interfaces reference local, uncommitted files at
`/etc/wireguard/wg1.conf` and `/etc/wireguard/wg3.conf`. `wg1` starts at boot;
`wg3` is available on demand with `sudo systemctl start wg-quick-wg3`.
Keep those files root-owned and mode `0600`, and do not copy their private keys
into this repository or the Nix store. Import and enable the module in the
host's NixOS configuration:

```nix
{
  inputs,
  ...
}:
{
  imports = [ inputs.dotfiles.nixosModules.wireguard ];

  dotfiles.wireguard = {
    enable = true;
  };
}
```

The secret file must be readable by root and contain a complete `wg-quick`
configuration, including `[Interface]` and `[Peer]` sections. To change the
defaults, set `dotfiles.wireguard.interfaces.<name>.{configFile,autostart}`;
each interface must have an explicit `autostart` value. Disable the module (or
the relevant interface's `autostart`) before intentionally removing its file.

## Forgejo Actions runner

The `home` host runs a self-hosted Forgejo Actions runner (via the
`services.gitea-actions-runner` NixOS module, compatible with Forgejo). CI jobs
execute directly on the host (labels `self-hosted:host`) — no Docker isolation,
but the local `/nix/store` is warm, so builds are fast.

The module is opt-in and imported from `hosts/home/configuration.nix`. Enable it
on another host:

```nix
{ inputs, ... }:
{
  imports = [ inputs.dotfiles.nixosModules.forgejo-runner ];

  dotfiles.forgejo-runner = {
    enable = true;
  };
}
```

### Secrets provisioning (one-time)

The runner fetches `git+ssh` flake inputs (`llama-server`, `opencode-mcp-tools`)
from the Forgejo instance at `10.10.0.101`. It needs an SSH deploy key and a
registration token, both provisioned out of band (like `/etc/wireguard/`).

> The `forgejo-runner` system user is created when the flake is deployed, so the
> SSH key step must come **after** the deploy. The runner will fail on first
> start (no key yet) — steps below account for that ordering.

```sh
# 1. Registration token — create one in Forgejo admin → Actions → Runners
#    (requires admin privilege; any Forgejo admin can generate one)
sudo mkdir -p /etc/forgejo-runner
sudo chmod 0700 /etc/forgejo-runner
echo 'TOKEN=<paste from Forgejo admin>' | sudo tee /etc/forgejo-runner/registration-token.env
sudo chmod 0600 /etc/forgejo-runner/registration-token.env

# 2. Deploy the flake (creates the forgejo-runner system user)
nix run ~/dotfiles-nix#home-switch

# 3. SSH deploy key — generate a read-only key (no passphrase) for flake inputs
#    chown works now because the user was created in step 2
sudo mkdir -p /var/lib/forgejo-runner/.ssh
ssh-keygen -t ed25519 -f /tmp/ci_key -N ""
sudo cp /tmp/ci_key /var/lib/forgejo-runner/.ssh/id_ed25519
sudo chmod 0700 /var/lib/forgejo-runner/.ssh
sudo chmod 0600 /var/lib/forgejo-runner/.ssh/id_ed25519
sudo chown -R forgejo-runner:forgejo-runner /var/lib/forgejo-runner/.ssh

# 4. Register the public key as a deploy key in each repo's settings
#    (Settings → Deploy keys) with **read-only** access, scoped per-repo:
#    - v/llama-server
#    - v/opencode-mcp-tools
#    The public key is still at /tmp/ci_key.pub until step 7.

# 5. Add the Forgejo host key to the runner's known_hosts
sudo -u forgejo-runner bash -c 'ssh-keyscan -H 10.10.0.101 >> /var/lib/forgejo-runner/.ssh/known_hosts 2>/dev/null || true'

# 6. Start the runner (it failed on first deploy — no key yet)
sudo systemctl start gitea-runner-home

# 7. Clean up temporary key files
rm -f /tmp/ci_key /tmp/ci_key.pub
```

After step 6, verify the runner appears in Forgejo admin → Actions. The service
registers automatically on first start and will persist across reboots.

## CI

Every push and pull request runs two parallel jobs on the self-hosted runner:

| Job             | What it does                           | Typical time |
|-----------------|----------------------------------------|-------------|
| `checks`        | `nix flake check` (packages + checks + apps) + home-manager build | ~5 min (cold) |
| `system-builds` | Full toplevel builds for both NixOS hosts + smoke-test deploy apps | ~5–30 min |

CI workflow: `.forgejo/workflows/ci.yml`. Run locally with:

```sh
nix flake check
```

`nix flake check` builds all packages (activate, deploy-host, capture-host,
set-default-shell), apps, and checks (toplevel configs, home-manager activation,
deploy-tools).

## deploy-host — single-stop deploy

Build and switch the NixOS system config + home-manager + default shell in one
command:

```sh
nix run ~/dotfiles-nix#deploy-host -- --host home
nix run ~/dotfiles-nix#deploy-host -- --host server
```

Options: `--skip-build` (skip pre-verification build), `--skip-home` (skip
home-manager activation), `--no-shell` (skip setting zsh as login shell).

## capture-host — snapshot live config into the repo

Copy the current `/etc/nixos/configuration.nix` and `hardware-configuration.nix`
into `hosts/<hostname>/`, rewriting absolute import paths to repo-relative
(`../../modules/...`) so the captured config is portable. Secrets in
`/etc/wireguard/` are never touched.

```sh
# Auto-detect host (nixos → home, server → server).
nix run ~/dotfiles-nix#capture-host

# Specify host explicitly.
nix run ~/dotfiles-nix#capture-host -- --host server

# Regenerate hardware config from the live system and use it.
nix run ~/dotfiles-nix#capture-host -- --generate-hardware

# Run a full nixos-rebuild build after capture to verify.
nix run ~/dotfiles-nix#capture-host -- --full-build
```

After capture, review the diff and commit. The tool adds a header with the
capture date and current system generation fingerprint.

First `nvim` launch bootstraps `lazy.nvim` against `dotfiles/nvim/lazy-lock.json`.
LSPs come from nixpkgs (`modules/nvim.nix`), not Mason. Inside tmux, `prefix + r`
reloads the tmux config without a rebuild.

## Editing configs

Files are copied into `/nix/store` at build time — edits to `dotfiles/**`
require `home-manager switch` to take effect. For live edits without rebuild,
swap the module's

```nix
xdg.configFile."<x>".source = ../dotfiles/<x>;
```

for

```nix
xdg.configFile."<x>".source =
  config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles-nix/dotfiles/<x>";
```

## Out of scope

- **NixOS system config** (kernel, drivers, display manager, i3 enable,
  nvidia, docker) — lives under `hosts/<name>/configuration.nix`.
- **Non-Nix toolchains** referenced from `zshrc`/`zprofile`: `.cargo/bin`,
  `.bun`, `.dotnet/tools`, `.opencode`, juliaup, pipx, perl5. Install
  separately; the PATH exports pick them up if the directories exist.

## Arch → NixOS notes

`zsh-syntax-highlighting` was originally sourced from `/usr/share/zsh/plugins/…`
(Arch). It is now provided by `pkgs.zsh-syntax-highlighting` and loaded via
oh-my-zsh's `plugins=(… zsh-syntax-highlighting)` list, symlinked into
`~/.config/zsh/custom/plugins/zsh-syntax-highlighting/` by `modules/zsh.nix`.
