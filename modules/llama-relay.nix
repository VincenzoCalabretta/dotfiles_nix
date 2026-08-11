{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.dotfiles.llama-relay;
in
{
  options.dotfiles.llama-relay = {
    enable = mkEnableOption ''
      firewall access to this host's llama-relay socket (see the
      systemd.user.sockets.llama-relay unit in modules/opencode.nix) over
      the wg1 WireGuard mesh, so another machine on wg1 can reach the local
      llama-server the same way it already reaches pve-remote's'';
  };

  config = mkIf cfg.enable {
    # Scoped to the wg1 interface only, not the raw Wi-Fi LAN - nothing else
    # on this host trusts that network the way it trusts the WireGuard mesh
    # (pve-remote, Forgejo). llama-server itself stays loopback-only
    # (127.0.0.1:8080); this only opens the separate relay port
    # (opencode.nix's llama-relay.socket, port 8090) that proxies to it.
    networking.firewall.interfaces.wg1.allowedTCPPorts = [ 8090 ];
  };
}
