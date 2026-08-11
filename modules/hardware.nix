{ pkgs, ... }:

{
  # Bazel's hermetic Rust toolchain contains generic Linux executables.  On
  # NixOS they need nix-ld to resolve their ELF interpreter and shared
  # libraries, otherwise host tools such as zub_ctl cannot be compiled.
  programs.nix-ld.enable = true;

  # The Raptor Lake audio controller needs the SOF DSP driver to expose the
  # laptop's analog speakers and headset jack (legacy HDA exposes HDMI only).
  boot.kernelParams = [
    "snd_intel_dspcfg.dsp_driver=3"
  ];
  boot.blacklistedKernelModules = [ "snd_soc_avs" ];

  # UCM incorrectly reports the connected Intel HDMI PCM as unavailable, so
  # WirePlumber selects the unavailable HiFi profile and leaves PipeWire with
  # a dummy output. Pro Audio exposes all HDMI PCMs; the node rules below keep
  # only the Dell's PCM visible.
  services.pipewire.wireplumber.extraConfig."51-intel-hdmi-pcms" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic";
          }
        ];
        actions.update-props."device.profile" = "pro-audio";
      }
      {
        matches = [
          {
            "node.name" = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.pro-output-2";
          }
          {
            "node.name" = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.pro-output-3";
          }
        ];
        actions.update-props."node.disabled" = true;
      }
      {
        matches = [
          {
            "node.name" = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.pro-output-1";
          }
        ];
        actions.update-props = {
          "node.description" = "Dell G2725D Headphone Out";
          "node.nick" = "Dell G2725D";
          "priority.session" = 2000;
        };
      }
    ];
  };

  # The pro-audio profile leaves the connected PCM's IEC958 transmitter muted
  # after WirePlumber initializes. Enable it once the card has been created.
  systemd.user.services.dell-hdmi-unmute = {
    description = "Unmute Dell HDMI headphone output";
    wantedBy = [ "wireplumber.service" ];
    after = [ "wireplumber.service" ];
    partOf = [ "wireplumber.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/sleep 2
      ${pkgs.alsa-utils}/bin/amixer -c sofhdadsp sset IEC958 unmute
    '';
  };

  # AES-ZUB-1CG-ED-G: FT2232H JTAG+UART adapter (OpenOCD). Official Xilinx
  # rule from Vivado's install_drivers package (52-xilinx-ftdi-usb.rules) —
  # the raw USB device node defaults to root:root and blocks libusb_open().
  services.udev.extraRules = ''
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{manufacturer}=="Xilinx", MODE:="666"
  '';
}
