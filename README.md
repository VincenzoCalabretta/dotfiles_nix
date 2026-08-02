# dotfiles-nix

Home-manager flake for tmux, neovim, zsh (oh-my-zsh), lf, i3.
Configs are shipped verbatim from `dotfiles/**` — no rewrite into Nix.
Modules provide every runtime dependency the configs reference.

## Layout

```
flake.nix          # inputs: nixpkgs (unstable) + home-manager
home.nix           # shared packages, programs.direnv, sessionPath, module imports
modules/
  tmux.nix         # tmux + python3 + xrandr           → ~/.config/tmux
  nvim.nix         # neovim + LSPs + build deps        → ~/.config/nvim
  zsh.nix          # zsh + oh-my-zsh + plugins         → ~/.zshrc, ~/.config/zsh
  lf.nix           # lf + archive tools + mimeopen     → ~/.config/lf
  i3.nix           # dmenu, i3status, rofi…            → ~/.config/i3
  ghostty.nix      # ghostty terminal                   → ~/.config/ghostty
  opencode.nix     # opencode + custom LLM endpoint     → ~/.config/opencode
dotfiles/          # verbatim source configs (tmux/ nvim/ zsh/ lf/ i3/ ghostty/ opencode/)
```

LLM providers go in `dotfiles/opencode/opencode.json`. OpenRouter is built-in:
export `OPENROUTER_API_KEY` (or `/connect` → OpenRouter) and select
`openrouter/deepseek/deepseek-v4-flash` via `/models`. The current config sets it
as the default model.

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

chsh -s "$(which zsh)"   # once, if zsh isn't your login shell
```

Later rebuilds (home-manager is on PATH after the first activation):

```sh
home-manager switch --flake ~/dotfiles-nix#v
```

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
