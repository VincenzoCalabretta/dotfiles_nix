{ lib, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;

  # Keep package and NixOS manuals, including separate developer outputs.
  documentation = {
    enable = lib.mkDefault true;
    man.enable = lib.mkDefault true;
    man.cache.enable = lib.mkDefault true;
    dev.enable = lib.mkDefault true;
    info.enable = lib.mkDefault true;
    doc.enable = lib.mkDefault true;
    nixos.enable = lib.mkDefault true;
  };

  environment.systemPackages = with pkgs; [
    man-pages
    man-pages-posix
  ];
}
