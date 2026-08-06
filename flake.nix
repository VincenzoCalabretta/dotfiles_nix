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
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./hosts/nixos/configuration.nix ];
      };

      # Import from a NixOS host configuration to deploy WireGuard as a
      # system service. It deliberately remains separate from home-manager:
      # creating network interfaces requires system privileges.
      nixosModules.wireguard = import ./modules/wireguard.nix;

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
      };

      apps.${system} = {
        nixos-build = {
          type = "app";
          program = "${pkgs.writeShellScript "nixos-build" ''
            exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild build --flake ${self}#nixos "$@"
          ''}";
        };

        nixos-switch = {
          type = "app";
          program = "${pkgs.writeShellScript "nixos-switch" ''
            exec sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ${self}#nixos "$@"
          ''}";
        };
      };
    };
}
