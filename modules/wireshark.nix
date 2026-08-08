{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.dotfiles.wireshark;
in
{
  options.dotfiles.wireshark = {
    enable = mkEnableOption "Wireshark with passwordless packet capture for wheel users";
  };

  config = mkIf cfg.enable {
    # Installs Wireshark and, critically, sets dumpcap's capabilities
    # (CAP_NET_RAW/CAP_NET_ADMIN) instead of setuid-root, so capture works
    # without sudo for anyone in the "wireshark" group.
    programs.wireshark.enable = true;

    # v is already in "wheel"; explicitly adding "wireshark" here documents
    # the dependency instead of relying on wheel members getting it for free.
    users.users.v.extraGroups = [ "wireshark" ];
  };
}
