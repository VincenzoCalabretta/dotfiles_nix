{ pkgs, ... }:

{
  # Packet capture for debugging the AES-ZUB-1CG board's Ethernet (GEM2/RGMII)
  # bring-up over the USB-Ethernet adapter. NOPASSWD is scoped to tcpdump only.
  environment.systemPackages = [ pkgs.tcpdump ];

  security.sudo.extraRules = [
    {
      users = [ "v" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/tcpdump";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
