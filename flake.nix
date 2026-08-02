{
  description = "v's home-manager configuration (tmux, nvim, zsh, lf, i3)";

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
      homeConfigurations."v" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
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
    };
}
