{ pkgs, ... }:

{
  home.packages = with pkgs; [
    tmux
    # tmux.conf and scripts reference these:
    python3        # randr_toggle_displays.py popup
    xrandr         # display switch script
    # xclip + fzf are shared (see home.nix).
  ];

  # tmux.conf sources ~/.config/tmux/tmux.conf and the scripts dir directly,
  # so symlinking the whole directory is enough.
  xdg.configFile."tmux".source = ../dotfiles/tmux;
}
