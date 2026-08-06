# dotfiles-nix

Home-manager flake for tmux, neovim, zsh (oh-my-zsh), lf, i3.
Configs are shipped verbatim from `dotfiles/**` — no rewrite into Nix.
Modules provide every runtime dependency the configs reference.

## Layout

```
flake.nix          # inputs: nixpkgs (unstable) + home-manager
home.nix           # shared packages, programs.direnv, sessionPath, module imports
hosts/nixos/       # versioned NixOS host configuration and hardware scan
modules/
  tmux.nix         # tmux + python3 + xrandr           → ~/.config/tmux
  nvim.nix         # neovim + LSPs + build deps        → ~/.config/nvim
  zsh.nix          # zsh + oh-my-zsh + plugins         → ~/.zshrc, ~/.config/zsh
  lf.nix           # lf + archive tools + mimeopen     → ~/.config/lf
  i3.nix           # dmenu, i3status, rofi…            → ~/.config/i3
  ghostty.nix      # ghostty terminal                   → ~/.config/ghostty
  opencode.nix     # opencode + local LLM + MCP tools    → ~/.config/opencode
  wireguard.nix    # opt-in NixOS WireGuard deployment  → wg-quick service
dotfiles/          # verbatim source configs (tmux/ nvim/ zsh/ lf/ i3/ ghostty/ opencode/)
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

The active `nixos` host configuration is versioned as the flake output
`nixosConfigurations.nixos`. It imports the reusable modules under `modules/`
and keeps the generated disk and boot description in
`hosts/nixos/hardware-configuration.nix`. The hardware file contains machine
identifiers and filesystem UUIDs, so it is specific to this host.

See [`hosts/nixos/README.md`](hosts/nixos/README.md) for the complete
validation, deployment, and rollback procedure.

Deployment is intentionally explicit; evaluating or updating this checkout
does not change the running system:

```sh
# Build and validate the next generation without activating it.
nix run ~/dotfiles-nix#nixos-build

# Build and activate it (requires sudo).
nix run ~/dotfiles-nix#nixos-switch
```

Before the first switch, compare `hosts/nixos/` with the live `/etc/nixos/`
configuration and commit the desired state. Regenerate the hardware file only
after hardware or partition-layout changes, then review and commit its diff.
WireGuard private keys remain outside the repository in `/etc/wireguard/`.

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
  nvidia, docker) — lives in `/etc/nixos/configuration.nix`.
- **Non-Nix toolchains** referenced from `zshrc`/`zprofile`: `.cargo/bin`,
  `.bun`, `.dotnet/tools`, `.opencode`, juliaup, pipx, perl5. Install
  separately; the PATH exports pick them up if the directories exist.

## Arch → NixOS notes

`zsh-syntax-highlighting` was originally sourced from `/usr/share/zsh/plugins/…`
(Arch). It is now provided by `pkgs.zsh-syntax-highlighting` and loaded via
oh-my-zsh's `plugins=(… zsh-syntax-highlighting)` list, symlinked into
`~/.config/zsh/custom/plugins/zsh-syntax-highlighting/` by `modules/zsh.nix`.
