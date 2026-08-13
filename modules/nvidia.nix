{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.dotfiles.nvidia;
in
{
  options.dotfiles.nvidia = {
    enable = mkEnableOption "NVIDIA proprietary driver for hybrid Intel/NVIDIA (PRIME offload) laptops";

    intelBusId = mkOption {
      type = types.str;
      description = ''
        Intel iGPU PCI bus ID in `lspci -nn | grep -Ei 'vga|3d'` /
        NixOS `PCI:bus:device:function` form (e.g. "PCI:0:2:0"). Specific to
        this machine's hardware topology — has no sane default.
      '';
    };

    nvidiaBusId = mkOption {
      type = types.str;
      description = ''
        NVIDIA dGPU PCI bus ID, same form as intelBusId (e.g. "PCI:1:0:0").
      '';
    };
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

        intelBusId = cfg.intelBusId;
        nvidiaBusId = cfg.nvidiaBusId;
      };
    };
  };
}
