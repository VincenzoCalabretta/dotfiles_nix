{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/tmux.nix
    ./modules/nvim.nix
    ./modules/zsh.nix
    ./modules/lf.nix
    ./modules/i3.nix
    ./modules/ghostty.nix
    ./modules/opencode.nix
    ./modules/rust.nix
  ];

  home.username = "v";
  home.homeDirectory = "/home/v";

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
    eza
    jq
    unzip
    unrar
    p7zip
    file
    wget
    curl
    xclip
    htop
    fastfetch
    lm_sensors           # sensors command

    # Fonts (nvim, terminals, i3 all expect a Nerd Font)
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code

    # Misc tools referenced from aliases or scripts
    highlight           # ccat alias in aliases.zsh

    # Dev toolchain — required by nvim LSPs and general use
    gcc
    gnumake
    pkg-config
    git

    # Programs
    keepassxc
    codex
    claude-code
  ];

  fonts.fontconfig.enable = true;
}
