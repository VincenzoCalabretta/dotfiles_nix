# dotfiles-nix

Home-manager flake for `v`'s core CLI/dev environment: **tmux, neovim, zsh
(oh-my-zsh), lf, i3**. Configs are shipped as verbatim files — no rewrite into
Nix — and the flake pulls in every runtime dependency the configs reference.

## Layout

```
flake.nix          # inputs: nixpkgs + home-manager
home.nix           # top-level HM config (shared packages, imports modules)
modules/
  tmux.nix         # tmux + xclip + fzf + python + xrandr, symlinks ~/.config/tmux
  nvim.nix         # neovim + LSPs + build deps, symlinks ~/.config/nvim
  zsh.nix          # zsh + oh-my-zsh + plugins, symlinks ~/.zshrc + ~/.config/zsh
  lf.nix           # lf + archive tools + xdg-utils + mimeopen, symlinks ~/.config/lf
  i3.nix           # i3 companions (dmenu, i3status, rofi, alacritty…), symlinks ~/.config/i3
dotfiles/          # verbatim copies of the source configs
  tmux/ nvim/ zsh/ lf/ i3/
```

## First-time setup on a fresh NixOS install

1. **System-level i3** — enable i3 as a window manager in your NixOS
   `configuration.nix` (this cannot be done from home-manager alone). Your
   existing `~/.config/nixos/configuration.nix` already has
   `services.xserver.windowManager.i3.enable = true;` — reuse it.

2. **Clone this repo** somewhere durable, e.g.:
   ```sh
   git clone <this-repo-url> ~/dotfiles-nix
   cd ~/dotfiles-nix
   ```

3. **Apply the home-manager configuration** (no need to install home-manager
   separately — this uses the flake's pinned version):
   ```sh
   nix run github:nix-community/home-manager -- switch --flake .#v
   ```

   Later rebuilds:
   ```sh
   home-manager switch --flake ~/dotfiles-nix#v
   ```

4. **Set zsh as your login shell** (once):
   ```sh
   chsh -s $(which zsh)
   ```

5. **Neovim first launch** — `lazy.nvim` will bootstrap and install every
   plugin listed in `dotfiles/nvim/lua/plugins/*.lua`, pinned via the
   `lazy-lock.json` also copied into the repo. Mason will pick up LSPs from
   nixpkgs (also installed via `modules/nvim.nix`), no Mason install needed.

6. **tmux prefix reload** — inside tmux: `prefix + r` reloads the config.

## Editing configs

Since files are copied into `/nix/store` at build time, edits to
`dotfiles/**` require a rebuild to take effect:

```sh
home-manager switch --flake ~/dotfiles-nix#v
```

If you want live edits without rebuild, swap `xdg.configFile.<x>.source =
../dotfiles/<x>;` for
`xdg.configFile.<x>.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles-nix/dotfiles/<x>";`
in the relevant module.

## What is NOT covered here

- **NixOS system config** (kernel, drivers, display manager, i3 enable, nvidia,
  docker, etc.) — lives in `/etc/nixos/configuration.nix`.
- **Terminals** (alacritty/ghostty/kitty configs). Only `alacritty` binary is
  installed here (referenced by i3). Add a `modules/alacritty.nix` if you want
  to ship its config too — the pattern is identical to `modules/lf.nix`.
- **Non-Nix package managers** referenced by `.zshrc` (`.cargo/bin`, `.bun`,
  `.dotnet/tools`, `.opencode`, juliaup, pipx). Install those separately as
  needed; the PATH exports in `.zprofile`/`.zshrc` will pick them up if the
  directories exist.

## Notes on config edits vs. Arch

The original `.zshrc` sourced
`/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh`,
an Arch-specific hardcoded path. It has been commented out in
`dotfiles/zsh/zshrc` — `zsh-syntax-highlighting` is now provided by
`pkgs.zsh-syntax-highlighting` and loaded by oh-my-zsh via the
`plugins=(… zsh-syntax-highlighting)` list, symlinked into
`~/.config/zsh/custom/plugins/zsh-syntax-highlighting/`.
