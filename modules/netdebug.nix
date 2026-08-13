{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.dotfiles.netdebug;
in
{
  options.dotfiles.netdebug = {
    enable = mkEnableOption "passwordless tcpdump for one user (e.g. for debugging Ethernet bring-up on embedded hardware)";

    user = mkOption {
      type = types.str;
      description = "User granted NOPASSWD sudo for tcpdump only.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tcpdump ];

    security.sudo.extraRules = [
      {
        users = [ cfg.user ];
        commands = [
          {
            command = "/run/current-system/sw/bin/tcpdump";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
