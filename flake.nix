{
  description = "v's home-manager configuration (tmux, nvim, zsh, lf, i3, Rust)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Self-hosted on the Forgejo instance also used by local_bazel_rag.
    # Fetching these as flake inputs (rather than assuming a sibling
    # ~/projects checkout) is what makes `home-manager switch` alone enough
    # to deploy opencode + its local model + MCP tools on a new machine —
    # see modules/opencode.nix for how they're wired in.
    #
    # Deliberately NOT `nixpkgs.follows`'d onto this flake's own nixpkgs:
    # llama-server in particular pins the exact nixpkgs revision its CUDA
    # llama.cpp build was already compiled and cached against, and these are
    # independent repos with their own release cadence, not part of this
    # monorepo — forcing a shared nixpkgs would invalidate that cache and
    # force a from-source CUDA rebuild for no real benefit.
    llama-server.url = "git+ssh://git@10.10.0.101/v/llama-server.git";
    opencode-mcp-tools.url = "git+ssh://git@10.10.0.101/v/opencode-mcp-tools.git";
  };

  outputs = { self, nixpkgs, home-manager, llama-server, opencode-mcp-tools, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # Versioned NixOS host configurations.  Building or switching one is
      # deliberately opt-in through the apps below.
      nixosConfigurations = {
        home = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./hosts/home/configuration.nix ];
        };
        server = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./hosts/server/configuration.nix ];
        };
      };

      # Import from a NixOS host configuration to deploy WireGuard as a
      # system service. It deliberately remains separate from home-manager:
      # creating network interfaces requires system privileges.
      nixosModules.wireguard = import ./modules/wireguard.nix;

      # Import from a NixOS host configuration to deploy a Forgejo Actions
      # runner that runs CI jobs on this machine (host execution, no Docker).
      nixosModules.forgejo-runner = import ./modules/forgejo-runner.nix;

      homeConfigurations."v" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
        extraSpecialArgs = { inherit llama-server opencode-mcp-tools; };
      };

      packages.${system} = {
        # Convenience alias: `nix run .#activate`
        activate = self.homeConfigurations."v".activationPackage;

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

      apps.${system} = {
        home-build = {
          type = "app";
          program = "${pkgs.writeShellScript "home-build" ''
            exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild build --flake ${self}#home "$@"
          ''}";
        };

        home-switch = {
          type = "app";
          program = "${pkgs.writeShellScript "home-switch" ''
            exec sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ${self}#home "$@"
          ''}";
        };

        server-build = {
          type = "app";
          program = "${pkgs.writeShellScript "server-build" ''
            exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild build --flake ${self}#server "$@"
          ''}";
        };

        server-switch = {
          type = "app";
          program = "${pkgs.writeShellScript "server-switch" ''
            exec sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ${self}#server "$@"
          ''}";
        };

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
        home-manager-build = self.homeConfigurations."v".activationPackage;
        system-server-toplevel = self.nixosConfigurations.server.config.system.build.toplevel;
        system-home-toplevel   = self.nixosConfigurations.home.config.system.build.toplevel;
        deploy-tools = pkgs.symlinkJoin {
          name = "deploy-tools";
          paths = with self.packages.${system}; [ activate set-default-shell deploy-host capture-host ];
        };

        # Proves CHECKLIST.md's automatable points actually hold — see
        # tests/checklist-vm.nix for what's covered and what's deliberately
        # out of scope (anything needing the real external Forgejo/hardware).
        checklist-vm = import ./tests/checklist-vm.nix {
          inherit pkgs;
          capture-host-script = ./tools/capture-host.sh;
          wireguard-module = ./modules/wireguard.nix;
          forgejo-runner-module = ./modules/forgejo-runner.nix;
          netdebug-module = ./modules/netdebug.nix;
          wireshark-module = ./modules/wireshark.nix;
        };

        # Fails if any CHECKLIST.md item is missing its manual/ci/test marker.
        checklist-coverage = pkgs.runCommand "checklist-coverage" { } ''
          ${pkgs.bash}/bin/bash ${./tools/check-checklist-coverage.sh} ${./CHECKLIST.md}
          touch $out
        '';
      };
    };
}
