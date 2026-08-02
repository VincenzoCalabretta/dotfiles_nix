{ pkgs, ... }:

# NOTE: enabling i3 as a window manager is a NixOS system-level concern
# (services.xserver.windowManager.i3). This module only provides the user-level
# config file and companion packages. Enable i3 itself in your NixOS
# configuration.nix.
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

    # xorg utilities exec'd from i3 config
    xorg.xset            # xset r rate 150 40
    xorg.setxkbmap       # caps:escape remap

    # systray / startup apps launched by i3 exec
    networkmanagerapplet # nm-applet
    seafile-client       # Seafile sync applet

    # Browsers / mail — exec'd from i3; move to system config if preferred
    firefox
    thunderbird
  ];

  xdg.configFile."i3".source = ../dotfiles/i3;
}
