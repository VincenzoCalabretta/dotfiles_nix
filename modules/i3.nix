{ pkgs, ... }:

# NOTE: enabling i3 as a window manager is a NixOS system-level concern
# (services.xserver.windowManager.i3). This module only provides the user-level
# config file and companion packages. Enable i3 itself in your NixOS
# configuration.nix (your existing ~/.config/nixos/configuration.nix already
# does this).
{
  home.packages = with pkgs; [
    # i3 companions and referenced launchers
    dmenu
    i3status
    i3blocks
    i3lock
    rofi
    feh
    picom
    xrandr
    arandr
    brightnessctl
    playerctl
    pulseaudio           # provides pactl for i3 volume bindings
    scrot
    maim
    slop

    # Terminals referenced from i3 config
    alacritty
  ];

  xdg.configFile."i3".source = ../dotfiles/i3;
}
