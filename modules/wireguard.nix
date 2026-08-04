{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.dotfiles.wireguard;
in
{
  options.dotfiles.wireguard = {
    enable = mkEnableOption "automatic WireGuard deployment";

    interfaces = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          configFile = mkOption {
            type = types.str;
            description = ''
              Path to the interface's wg-quick configuration file. Keep it
              outside the Nix store because it normally contains a private key.
            '';
          };

          autostart = mkOption {
            type = types.bool;
            default = false;
            description = "Bring this interface up automatically at boot.";
          };
        };
      });
      default = {
        wg1 = {
          configFile = "/etc/wireguard/wg1.conf";
          autostart = true;
        };
        wg3 = {
          configFile = "/etc/wireguard/wg3.conf";
          autostart = false;
        };
      };
      description = "WireGuard interfaces to deploy.";
    };
  };

  config = mkIf cfg.enable {
    # NixOS supplies wireguard-tools and creates wg-quick-<interface>.service.
    # Services whose autostart flag is true are enabled at boot and all are
    # reconciled on every `nixos-rebuild switch`.
    networking.wg-quick.interfaces = cfg.interfaces;
  };
}
