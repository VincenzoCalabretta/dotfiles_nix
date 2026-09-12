{ ... }:

{
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;
}