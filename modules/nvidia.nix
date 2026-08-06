{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.dotfiles.nvidia;
in
{
  options.dotfiles.nvidia = {
    enable = mkEnableOption "NVIDIA proprietary driver for hybrid Intel/NVIDIA (PRIME offload) laptops";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics.enable = true;

    hardware.nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;

      # Closed-source kernel module: newest hardware (Ada Lovelace+) is well
      # supported by the open module, but "proprietary" was requested
      # explicitly and it remains the safer default for suspend/resume.
      open = false;

      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Lets the dGPU power down when idle; required for PRIME offload to
      # actually save battery instead of keeping the card powered at all times.
      powerManagement.enable = true;
      powerManagement.finegrained = true;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true; # provides the `nvidia-offload` wrapper
        };

        # Intel iGPU at 0000:00:02.0, NVIDIA dGPU at 0000:01:00.0
        # (`lspci -nn | grep -Ei 'vga|3d'`). Update if hardware changes.
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
}
