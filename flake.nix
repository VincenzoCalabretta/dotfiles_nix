{
  description = "Generic, reusable NixOS/Home Manager module library (tmux, nvim, zsh, lf, i3, Rust, WireGuard, ...) — no personal packages, secrets, or private infrastructure. Concrete personal deployments (hosts, private local-AI stack) live in a separate private overlay repo that imports this one.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # Import from a NixOS host configuration to deploy WireGuard as a
      # system service. It deliberately remains separate from home-manager:
      # creating network interfaces requires system privileges.
      nixosModules.wireguard = import ./modules/wireguard.nix;

      # Import from a NixOS host configuration to deploy a Forgejo Actions
      # runner that runs CI jobs on this machine (host execution, no Docker).
      nixosModules.forgejo-runner = import ./modules/forgejo-runner.nix;

      # Small, generic, opt-in NixOS building blocks — safe to reuse on any
      # host. (Machine-specific quirk modules, e.g. this laptop's own
      # audio/USB-device fixes, don't live here at all — they're colocated
      # with the one host they apply to, in the private overlay repo.)
      nixosModules.nixos-base = import ./modules/nixos-base.nix;
      nixosModules.nvidia = import ./modules/nvidia.nix;
      nixosModules.wireshark = import ./modules/wireshark.nix;
      nixosModules.netdebug = import ./modules/netdebug.nix;
      nixosModules.compiler-explorer = import ./modules/compiler-explorer.nix;

      # Generic terminal/editor/shell Home Manager profile: no personal
      # packages, no private flake inputs, no baked-in username/home
      # directory. Import from an external flake's own home.nix alongside
      # your own home.username/homeDirectory and extras — see
      # home.nix.example.
      homeManagerModules.base = import ./home.nix;

      # Proves the base profile evaluates and activates on its own, with no
      # private flake inputs reachable — this is what an external (e.g.
      # work-machine) flake gets from homeManagerModules.base. The real
      # personal deployment (homeConfigurations."v") lives in the private
      # overlay repo, which also defines its own packages.activate.
      homeConfigurations."example" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          {
            home.username = "example";
            home.homeDirectory = "/home/example";
          }
        ];
      };

      packages.${system} = {
        compiler-explorer = pkgs.callPackage ./packages/compiler-explorer.nix { };

        # Set the login shell to zsh: `nix run .#set-default-shell`
        set-default-shell =
          pkgs.writeShellScriptBin "set-default-shell" ''
            exec chsh -s "$(command -v zsh)"
          '';

        # Single-stop deploy: nixos-rebuild switch + home-manager + shell
        deploy-host = pkgs.writeShellScriptBin "deploy-host" ''
          exec ${./tools/deploy-host.sh} --flake "${self}" "$@"
        '';

        # Snapshot live /etc/nixos/* into the repo with portable imports
        capture-host = pkgs.writeShellScriptBin "capture-host" ''
          exec ${./tools/capture-host.sh} "$@"
        '';
      };

      # No home-build/home-switch/server-build/server-switch here — this repo
      # ships no concrete hosts of its own. Consumers build/switch their own
      # flake's nixosConfigurations directly (`nixos-rebuild switch --flake
      # <yours>#<host>`), or reuse deploy-host/capture-host below with
      # `--flake <yours>`.
      apps.${system} = {
        deploy-host = {
          type = "app";
          program = "${self.packages.${system}.deploy-host}/bin/deploy-host";
        };

        capture-host = {
          type = "app";
          program = "${self.packages.${system}.capture-host}/bin/capture-host";
        };
      };

      # CI checks. `nix flake check` builds everything: packages, apps, checks.
      checks.${system} = {
        # Base profile only, no private inputs reachable — proves portability.
        home-manager-build = self.homeConfigurations."example".activationPackage;
        deploy-tools = pkgs.symlinkJoin {
          name = "deploy-tools";
          paths = with self.packages.${system}; [ set-default-shell deploy-host capture-host ];
        };

        # Proves the shared NixOS modules (wireguard, forgejo-runner,
        # netdebug, wireshark) produce the state their option docs promise —
        # users, permissions, systemd units, group membership — independent
        # of any concrete host. See tests/checklist-vm.nix for what's covered
        # and what's deliberately out of scope (anything needing real
        # hardware or the external Forgejo instance).
        checklist-vm = import ./tests/checklist-vm.nix {
          inherit pkgs;
          capture-host-script = ./tools/capture-host.sh;
          wireguard-module = ./modules/wireguard.nix;
          forgejo-runner-module = ./modules/forgejo-runner.nix;
          netdebug-module = ./modules/netdebug.nix;
          wireshark-module = ./modules/wireshark.nix;
        };
        compiler-explorer-vm = import ./tests/compiler-explorer-vm.nix {
          inherit pkgs;
          compiler-explorer-module = ./modules/compiler-explorer.nix;
        };
        compiler-explorer-home-manager-vm = import ./tests/compiler-explorer-home-manager-vm.nix {
          inherit pkgs home-manager;
          nvim-module = ./modules/nvim.nix;
        };
        compiler-explorer-project = pkgs.runCommand "compiler-explorer-project-test" {
          nativeBuildInputs = [ pkgs.neovim ];
        } ''
          export HOME="$TMPDIR"
          nvim --headless --clean -u NONE \
            '+set runtimepath+=${./dotfiles/nvim}' \
            '+luafile ${./tests/compiler-explorer-project.lua}' \
            +qa
          touch "$out"
        '';
        compiler-explorer-asm-help = pkgs.runCommand "compiler-explorer-asm-help-test" {
          nativeBuildInputs = [ pkgs.neovim ];
        } ''
          export HOME="$TMPDIR"
          nvim --headless --clean -u NONE \
            '+set runtimepath+=${./dotfiles/nvim}' \
            '+luafile ${./tests/compiler-explorer-asm-help.lua}' \
            +qa
          touch "$out"
        '';
        nvim-game = pkgs.runCommand "nvim-game-test" {
          nativeBuildInputs = [ pkgs.neovim ];
        } ''
          export HOME="$TMPDIR"
          nvim --headless --clean -u NONE \
            '+set runtimepath+=${./dotfiles/nvim}' \
            '+luafile ${./tests/nvim-game.lua}' \
            +qa
          touch "$out"
        '';

        # Runs dotfiles/nvim/lua/dap_modules' own plenary test suite and
        # renders its line-coverage HTML report (see
        # dotfiles/nvim/lua/dap_modules/README.md's "Testing" section) as a
        # hermetic, sandboxed build — no lazy.nvim install or network access
        # needed, since the handful of plugins that suite requires
        # (plenary/nvim-dap/nvim-dap-view/telescope/telescope-dap) come from
        # nixpkgs' vimPlugins instead. `nix build
        # .#checks.x86_64-linux.dap-modules-coverage -o out/dap-modules-coverage`
        # then puts the report at out/dap-modules-coverage/index.html.
        # Fails the build (and so `nix flake check`) if any test fails,
        # same as the two compiler-explorer checks above.
        dap-modules-coverage = pkgs.runCommand "dap-modules-coverage" {
          nativeBuildInputs = [ pkgs.neovim ];
        } ''
          export HOME="$TMPDIR"
          export DAP_MODULES_TEST_PLUGIN_PATHS="${pkgs.vimPlugins.plenary-nvim}:${pkgs.vimPlugins.nvim-dap}:${pkgs.vimPlugins.nvim-dap-view}:${pkgs.vimPlugins.telescope-nvim}:${pkgs.vimPlugins.telescope-dap-nvim}"

          tests_dir="${./dotfiles/nvim}/lua/dap_modules/tests"
          data_dir="$TMPDIR/coverage-data"
          mkdir -p "$data_dir" "$out"

          export DAP_MODULES_COVERAGE_DIR="$data_dir"
          nvim --headless --noplugin -u "$tests_dir/minimal_init.lua" \
            -c "PlenaryBustedDirectory $tests_dir { minimal_init = '$tests_dir/minimal_init.lua' }"

          nvim -l "$tests_dir/render_coverage.lua" \
            "$data_dir" "$out/index.html" \
            "${./dotfiles/nvim}/lua/dap_modules" "${./dotfiles/nvim}/lua/bazel_picker.lua"
        '';
      };
    };
}
