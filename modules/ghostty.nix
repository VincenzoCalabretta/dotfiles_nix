{ pkgs, ... }:

# ghostty is the terminal emulator launched by i3 and tmux sessions.
{
  home.packages = with pkgs; [
    ghostty
  ];

  xdg.configFile."ghostty/config".source =
    ../dotfiles/ghostty/config;
}
