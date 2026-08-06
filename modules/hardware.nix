{ ... }:

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

  # AES-ZUB-1CG-ED-G: FT2232H JTAG+UART adapter (OpenOCD). Official Xilinx
  # rule from Vivado's install_drivers package (52-xilinx-ftdi-usb.rules) —
  # the raw USB device node defaults to root:root and blocks libusb_open().
  services.udev.extraRules = ''
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{manufacturer}=="Xilinx", MODE:="666"
  '';
}
