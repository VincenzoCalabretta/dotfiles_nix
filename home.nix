{ config, pkgs, lib, ... }:

# Generic, reusable Home Manager profile: terminal/editor/shell tooling with
# no personal packages, private flake inputs, or baked-in username/home
# directory. Exposed as `homeManagerModules.base` in flake.nix so any
# consuming flake (this repo's own home-personal.nix, or an external one) can
# import it and layer its own home.username/homeDirectory and machine- or
# person-specific extras (opencode/claude, personal packages, i3 exec'd apps,
# ...) on top. See home.nix.example for how an external flake does this.
{
  imports = [
    ./modules/tmux.nix
    ./modules/nvim.nix
    ./modules/zsh.nix
    ./modules/bash.nix
    ./modules/lf.nix
    ./modules/i3.nix
    ./modules/ghostty.nix
    ./modules/rust.nix
  ];

  # Match the release you're installing home-manager from. Update in lockstep
  # with the nixpkgs branch pinned in flake.nix.
  home.stateVersion = "24.11";

  # Puts tmux/i3 helper scripts (tmux-sessionizer, randr_toggle_displays.py, …)
  # on PATH so config files can invoke them by bare name.
  home.sessionPath = [ "${config.home.homeDirectory}/.config/tmux/scripts" ];

  # The X session here is started manually via `startx`/xinit (no display
  # manager), so nothing else sources home-manager's session-vars script —
  # home.sessionPath above would silently never reach i3, ghostty, or the
  # tmux server without this. Managing .xinitrc declaratively keeps that
  # wiring reproducible instead of depending on a hand-edited file in $HOME.
  home.file.".xinitrc".text = ''
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    exec i3
  '';

  programs.home-manager.enable = true;

  # Home-manager sets up the zsh hook and pulls in nix-direnv automatically.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Shared base packages. Tool-specific runtime deps live in their module.
  home.packages = with pkgs; [
    # Shell / terminal essentials
    ripgrep
    fd
    fzf
    bat
    eza                     # modern ls replacement (icons, git status, tree view)
    jq
    unzip
    unrar                    # extracts .rar archives
    p7zip                    # extracts/creates .7z archives
    file
    wget
    curl
    xclip                    # CLI clipboard access (used by yank binds)
    htop
    fastfetch                # neofetch-style system info summary
    lm_sensors           # sensors command
    ncdu                  # interactive disk usage analyzer
    wireshark             # network protocol analyzer / packet capture (passwordless capture set up via dotfiles.wireshark, hosts/home)

    # Fonts (nvim, terminals, i3 all expect a Nerd Font)
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code

    # Misc tools referenced from aliases or scripts
    highlight           # ccat alias in aliases.zsh
    imagemagick          # import, convert, mogrify, etc.

    # Dev toolchain — required by nvim LSPs and general use
    gcc
    gnumake
    pkg-config           # locates library compile/link flags for builds
    git
  ];

  fonts.fontconfig.enable = true;
}
