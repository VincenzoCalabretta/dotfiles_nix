{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/tmux.nix
    ./modules/nvim.nix
    ./modules/zsh.nix
    ./modules/lf.nix
    ./modules/i3.nix
  ];

  home.username = "v";
  home.homeDirectory = "/home/v";

  # Match the release you're installing home-manager from. Update in lockstep
  # with the nixpkgs branch pinned in flake.nix.
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # Packages that don't belong to a specific tool module.
  # Tool-specific runtime deps live next to their module.
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
    xsel

    # Fonts (nvim, terminals, i3 all expect a Nerd Font)
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code

    # Dev toolchain — required by nvim LSPs and general use
    gcc
    gnumake
    pkg-config
    git

    # Direnv (used from zshrc)
    direnv
  ];

  fonts.fontconfig.enable = true;
}
