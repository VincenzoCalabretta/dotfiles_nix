{ pkgs, ... }:

{
  home.packages = with pkgs; [
    tmux
    # tmux.conf and scripts reference these:
    python3        # randr_toggle_displays.py popup
    xclip          # copy-mode-vi y -> xclip
    fzf            # tmux-sessionizer picker
    xrandr         # display switch script
  ];

  # tmux.conf sources ~/.config/tmux/tmux.conf and the scripts dir directly,
  # so symlinking the whole directory is enough.
  xdg.configFile."tmux".source = ../dotfiles/tmux;
}
