{
  description = "devShell for the leetcode.nvim debug workspace: Bazel (via bazelisk, honoring .bazelversion) + the C++ toolchain + gdb/gdbserver dap_modules needs.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # dap_modules' bazel_picker defaults to invoking a binary literally
      # named "bazel" (see the public repo's dap_modules/project.lua). This
      # wrapper gives it exactly that, while still honoring .bazelversion's
      # 9.1.0 pin via bazelisk underneath, instead of nixpkgs' own (often
      # lagging) `bazel_*` package versions.
      bazel = pkgs.writeShellScriptBin "bazel" ''
        exec ${pkgs.bazelisk}/bin/bazelisk "$@"
      '';
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          bazel
          pkgs.gcc      # rules_cc's default toolchain
          pkgs.gdb      # gdb + gdbserver, for dap_modules' gdbnf config
        ];

        # Bazel's --run_under (used by .bazelrc's gdbnf config to launch
        # under gdbserver) hardcodes /bin/bash, which doesn't exist on
        # NixOS (only /bin/sh) -- confirmed by a real `bazel run
        # --config=gdbnf` failing with "execv of '/bin/bash' failed: No
        # such file or directory". BAZEL_SH is the variable Bazel checks
        # first, before falling back to the hardcoded path.
        BAZEL_SH = "${pkgs.bash}/bin/bash";
      };
    };
}
