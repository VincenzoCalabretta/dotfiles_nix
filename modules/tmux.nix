{ pkgs, ... }:

{
  home.packages = with pkgs; [
    tmux
    # tmux.conf and scripts reference these:
    python3        # randr_toggle_displays.py popup
    xrandr         # display switch script
    libnotify      # notify-send in tmux-nrdp
    # xclip + fzf are shared (see home.nix).
  ];

  xdg.configFile."tmux/tmux.conf".text = ''
    set-option -g default-shell ${pkgs.zsh}/bin/zsh
  '' + builtins.readFile ../dotfiles/tmux/tmux.conf;

  xdg.configFile."tmux/tmux_i3_like.conf".source =
    ../dotfiles/tmux/tmux_i3_like.conf;

  xdg.configFile."tmux/scripts".source =
    ../dotfiles/tmux/scripts;
}
