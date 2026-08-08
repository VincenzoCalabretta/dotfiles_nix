# dotfiles-nix

Home-manager flake for tmux, neovim, zsh, lf, i3. Configs ship from 
`dotfiles/**`; Nix modules provide the runtime deps they
reference.

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
  ghostty.nix      # ghostty terminal                  → ~/.config/ghostty
  opencode.nix     # opencode + local LLM + MCP tools  → ~/.config/opencode
  wireguard.nix    # opt-in NixOS WireGuard deployment → wg-quick service
  forgejo-runner.nix # opt-in Forgejo Actions runner   → gitea-runner service
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

`home.sessionPath` prepends `~/.config/tmux/scripts` so helpers
(`tmux-sessionizer`, `randr_toggle_displays.py`, `tmux-cht.sh`, …) resolve by
bare name from tmux/i3 bindings.

OpenCode uses a local llama.cpp server plus MCP tools (web search, structural
code search, a test/build feedback loop, structured output), both built from
Forgejo flake inputs (`10.10.0.101`) rather than a manual checkout.
`home-manager switch` deploys it; then:

```sh
systemctl --user start llama-server opencode-searxng
opencode
```

See [`dotfiles/opencode/README.md`](dotfiles/opencode/README.md) for details.

## Activate on a new machine

Prerequisites:
- NixOS with flakes enabled: `nix.settings.experimental-features = [ "nix-command" "flakes" ];`
- For i3: `services.xserver.windowManager.i3.enable = true;` in
  `/etc/nixos/configuration.nix` (home-manager cannot enable a WM)

```sh
git clone ssh://git@10.10.0.101/v/dotfiles_nix.git ~/dotfiles-nix
cd ~/dotfiles-nix

# First activation. -b backup renames any pre-existing conflicting file
# (~/.zshrc, ~/.config/{nvim,tmux,i3,lf,zsh}, …) to <name>.backup before
# symlinking. Drop -b backup on a truly empty $HOME.
nix run github:nix-community/home-manager -- switch -b backup --flake .#v
```

This also sets your login shell to zsh via a `home.activation` hook
(requires zsh in `/etc/shells`; add `environment.shells = [ pkgs.zsh ];` if
`chsh` refuses). `nix run .#set-default-shell` does the same manually.

Later rebuilds (home-manager is on PATH after the first activation):

```sh
home-manager switch --flake ~/dotfiles-nix#v
```

## NixOS host configuration

| Host     | Profile  | Key modules                                       |
|----------|----------|----------------------------------------------------|
| `home`   | Desktop  | nvidia, i3, WireGuard, wireshark, laptop hardware  |
| `server` | Headless | WireGuard (minimal, no display)                    |

Both share a base via `modules/nixos-base.nix` (zsh, openssh, flakes,
allowUnfree). Machine-specific settings live in each host's own
`configuration.nix` / `hardware-configuration.nix`. Full deployment
procedures: [`hosts/home/README.md`](hosts/home/README.md),
[`hosts/server/README.md`](hosts/server/README.md).

Evaluating or checking this repo never changes the running system —
deployment only happens via `deploy-host`, which runs the NixOS switch,
home-manager activation, and default-shell setup in one step:

```sh
nix run ~/dotfiles-nix#deploy-host -- --host home
nix run ~/dotfiles-nix#deploy-host -- --host server
```

Options: `--skip-build`, `--skip-home`, `--no-shell`.

Individual steps, for manual use:

```sh
nix run ~/dotfiles-nix#home-build     # desktop: build only
nix run ~/dotfiles-nix#home-switch    # desktop: build + activate (sudo)
nix run ~/dotfiles-nix#server-build   # server: build only
nix run ~/dotfiles-nix#server-switch  # server: deploy locally or via SSH
```

Before the first switch on a machine, compare `hosts/<name>/` against the
live `/etc/nixos/` config and commit the desired state:

```sh
nix run ~/dotfiles-nix#capture-host
```

Regenerate the hardware file only after hardware or partition changes, then
review and commit its diff. WireGuard private keys stay outside the repo, in
`/etc/wireguard/`.

## WireGuard

Deployed by NixOS (not home-manager) since bringing up an interface needs
system privileges. The flake exports an opt-in module that starts
`wg-quick-wg1.service` at boot and reconciles both interfaces on every
`nixos-rebuild switch`.

The default interfaces point at local, uncommitted files:
`/etc/wireguard/wg1.conf` (autostarts) and `/etc/wireguard/wg3.conf` (manual —
`sudo systemctl start wg-quick-wg3`). Keep these root-owned, mode `0600`, and
never commit their private keys.

```nix
{ inputs, ... }:
{
  imports = [ inputs.dotfiles.nixosModules.wireguard ];
  dotfiles.wireguard.enable = true;
}
```

Each secret file needs a complete `wg-quick` config (`[Interface]` +
`[Peer]`). Override via `dotfiles.wireguard.interfaces.<name>.{configFile,autostart}`
— `autostart` is required per interface. Disable the module (or an
interface's `autostart`) before removing its file.

## Forgejo Actions runner

The `home` host runs a self-hosted runner (`services.gitea-actions-runner`,
Forgejo-compatible) with jobs executing directly on the host — no Docker
isolation, but a warm `/nix/store` keeps builds fast. Opt-in, imported from
`hosts/home/configuration.nix`:

```nix
{ inputs, ... }:
{
  imports = [ inputs.dotfiles.nixosModules.forgejo-runner ];
  dotfiles.forgejo-runner.enable = true;
}
```

### Secrets provisioning (one-time)

The runner fetches `git+ssh` flake inputs (`llama-server`,
`opencode-mcp-tools`) from Forgejo at `10.10.0.101`, needing an SSH deploy key
and registration token provisioned out of band (like `/etc/wireguard/`). The
`forgejo-runner` system user is created on deploy, so the SSH key step must
come **after** it — the runner fails on first start (no key yet) and that's
expected.

```sh
# 1. Registration token (Forgejo admin → Actions → Runners)
sudo mkdir -p /etc/forgejo-runner
sudo chmod 0700 /etc/forgejo-runner
echo 'TOKEN=<paste from Forgejo admin>' | sudo tee /etc/forgejo-runner/registration-token.env
sudo chmod 0600 /etc/forgejo-runner/registration-token.env

# 2. Deploy the flake (creates the forgejo-runner system user)
nix run ~/dotfiles-nix#home-switch

# 3. SSH deploy key (read-only, no passphrase)
ssh-keygen -t ed25519 -f /tmp/ci_key -N ""
sudo mkdir -p /var/lib/forgejo-runner/.ssh
sudo cp /tmp/ci_key /var/lib/forgejo-runner/.ssh/id_ed25519
sudo chmod 0700 /var/lib/forgejo-runner/.ssh
sudo chmod 0600 /var/lib/forgejo-runner/.ssh/id_ed25519
sudo chown -R forgejo-runner:forgejo-runner /var/lib/forgejo-runner/.ssh

# 4. Register /tmp/ci_key.pub as a read-only deploy key in each repo's
#    Settings → Deploy keys: v/llama-server, v/opencode-mcp-tools

# 5. Trust the Forgejo host key
sudo -u forgejo-runner bash -c 'ssh-keyscan -H 10.10.0.101 >> /var/lib/forgejo-runner/.ssh/known_hosts 2>/dev/null || true'

# 6. Start the runner (it failed on first deploy — no key yet)
sudo systemctl start gitea-runner-home

# 7. Clean up
rm -f /tmp/ci_key /tmp/ci_key.pub
```

After step 6, confirm the runner appears in Forgejo admin → Actions — it
registers itself on first start and persists across reboots.

## CI

Every push and PR runs two parallel jobs on the self-hosted runner:

| Job             | What it does                                                                  | Typical time |
|-----------------|--------------------------------------------------------------------------------|-------------|
| `checks`        | `nix flake check` (packages + checks + apps) + home-manager build + CHECKLIST.md coverage/VM test | ~5 min (cold) |
| `system-builds` | Full toplevel builds for both NixOS hosts + smoke-test deploy apps            | ~5–30 min   |

Workflow: `.forgejo/workflows/ci.yml`. Run locally:

```sh
nix flake check
```

`nix flake check` already covers the CHECKLIST.md checks (`checklist-coverage`,
`checklist-vm`); the dedicated `checks` job just gives them their own named,
untruncated CI log entries.

## capture-host — snapshot live config into the repo

Copies `/etc/nixos/configuration.nix` and `hardware-configuration.nix` into
`hosts/<hostname>/`, rewriting absolute imports to repo-relative
(`../../modules/...`). Never touches `/etc/wireguard/` secrets.

```sh
nix run ~/dotfiles-nix#capture-host                          # auto-detect host
nix run ~/dotfiles-nix#capture-host -- --host server          # explicit host
nix run ~/dotfiles-nix#capture-host -- --generate-hardware    # regen hardware config
nix run ~/dotfiles-nix#capture-host -- --full-build           # verify with a full build
```

Review the diff and commit — the tool stamps a header with capture date and
system generation.

## Editing configs

`dotfiles/**` is copied into `/nix/store` at build time, so edits need
`home-manager switch` to take effect. First `nvim` launch bootstraps
`lazy.nvim` against `dotfiles/nvim/lazy-lock.json` (LSPs come from nixpkgs via
`modules/nvim.nix`, not Mason). Inside tmux, `prefix + r` reloads the config
without a rebuild.

For live edits without a rebuild, swap a module's

```nix
xdg.configFile."<x>".source = ../dotfiles/<x>;
```

for

```nix
xdg.configFile."<x>".source =
  config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles-nix/dotfiles/<x>";
```
