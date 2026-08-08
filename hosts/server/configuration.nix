{ pkgs, ... }:

{
  imports = [
    ../../modules/nixos-base.nix
    ./hardware-configuration.nix
    ../../modules/wireguard.nix
  ];

  dotfiles.wireguard.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "server";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Rome";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.v = {
    isNormalUser = true;
    description = "v";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [ vim wget git neovim ];

  system.stateVersion = "26.05";
}