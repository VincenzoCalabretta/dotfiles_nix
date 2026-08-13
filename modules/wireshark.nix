{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.dotfiles.wireshark;
in
{
  options.dotfiles.wireshark = {
    enable = mkEnableOption "Wireshark with passwordless packet capture for wheel users";

    user = mkOption {
      type = types.str;
      description = "User to add to the \"wireshark\" group for passwordless capture.";
    };
  };

  config = mkIf cfg.enable {
    # Installs Wireshark and, critically, sets dumpcap's capabilities
    # (CAP_NET_RAW/CAP_NET_ADMIN) instead of setuid-root, so capture works
    # without sudo for anyone in the "wireshark" group.
    programs.wireshark.enable = true;

    # Assumes cfg.user is already in "wheel"; explicitly adding "wireshark"
    # here documents the dependency instead of relying on wheel members
    # getting it for free.
    users.users.${cfg.user}.extraGroups = [ "wireshark" ];
  };
}
