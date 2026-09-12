-- Nix flake snippets. Bodies use LSP/TextMate tabstop syntax ($1, ${1:default},
-- $0 for final cursor). Nix's own string interpolation also uses `${...}`,
-- which collides with that syntax -- every literal nix interpolation below is
-- written `\${...}` so the snippet parser emits it as plain text instead of
-- trying to parse it as a tabstop/variable.
local ls = require 'luasnip'
local parse = ls.parser.parse_snippet

---@type { [1]: string, [2]: string, [3]: string }[]
local defs = {
  -- New flake skeletons
  {
    'flake',
    'New flake.nix: description + inputs + single-system outputs',
    [[
{
  description = "$1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "${2:x86_64-linux}";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = [ $3 ];
      };

      packages.\${system}.default = $0;
    };
}]],
  },
  {
    'flakemin',
    'Minimal flake.nix: bare description/inputs/outputs',
    [[
{
  description = "$1";

  inputs = { };

  outputs = inputs: {
    $0
  };
}]],
  },
  {
    'flakeutils',
    'New flake.nix using flake-utils.lib.eachDefaultSystem',
    [[
{
  description = "$1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.\${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [ $2 ];
        };

        packages.default = $0;
      });
}]],
  },
  {
    'flakeparts',
    'New flake.nix using flake-parts.lib.mkFlake',
    [[
{
  description = "$1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { pkgs, system, ... }: {
        devShells.default = pkgs.mkShell {
          buildInputs = [ $2 ];
        };

        packages.default = $0;
      };
    };
}]],
  },

  -- inputs
  {
    'input',
    'Generic flake input (name.url = ...)',
    [[${1:name}.url = "${2:github:owner/repo}";$0]],
  },
  {
    'inputgh',
    'GitHub-hosted flake input with optional ref',
    [[${1:name}.url = "github:${2:owner}/${3:repo}${4:/ref}";$0]],
  },
  {
    'inputflw',
    'Flake input that follows the top-level nixpkgs',
    [[
${1:name} = {
  url = "${2:github:owner/repo}";
  inputs.nixpkgs.follows = "nixpkgs";
};$0]],
  },
  {
    'inputflakeutils',
    'flake-utils input',
    [[flake-utils.url = "github:numtide/flake-utils";$0]],
  },
  {
    'inputflakeparts',
    'flake-parts input',
    [[flake-parts.url = "github:hercules-ci/flake-parts";$0]],
  },
  {
    'inputhm',
    'home-manager input, following nixpkgs',
    [[
home-manager = {
  url = "github:nix-community/home-manager";
  inputs.nixpkgs.follows = "nixpkgs";
};$0]],
  },

  -- outputs helpers
  {
    'outputs',
    'outputs function signature',
    [[
outputs = { self, nixpkgs, ${1:...} }:
  $0]],
  },
  {
    'eachsystem',
    'forAllSystems helper via nixpkgs.lib.genAttrs',
    [[
let
  systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  forAllSystems = nixpkgs.lib.genAttrs systems;
in
  forAllSystems (system:
    let
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      $0
    })]],
  },
  {
    'persystem',
    'flake-parts perSystem block',
    [[
perSystem = { pkgs, system, ... }: {
  $0
};]],
  },

  -- devShells
  {
    'devshell',
    'devShells.default = pkgs.mkShell { ... }',
    [[
devShells.default = pkgs.mkShell {
  buildInputs = [ $1 ];
  $0
};]],
  },
  {
    'devshellhook',
    'devShell with a shellHook',
    [[
devShells.default = pkgs.mkShell {
  buildInputs = [ $1 ];

  shellHook = ''
    $0
  '';
};]],
  },
  {
    'devshellmulti',
    'devShells attrset across forAllSystems',
    [[
devShells = forAllSystems (system:
  let
    pkgs = nixpkgs.legacyPackages.\${system};
  in {
    default = pkgs.mkShell {
      buildInputs = [ $0 ];
    };
  });]],
  },

  -- packages
  {
    'package',
    'packages.default via callPackage',
    [[packages.default = pkgs.callPackage ${1:./default.nix} { };$0]],
  },
  {
    'derivation',
    'pkgs.stdenv.mkDerivation skeleton',
    [[
pkgs.stdenv.mkDerivation {
  pname = "$1";
  version = "$2";

  src = $3;

  buildInputs = [ $4 ];
  nativeBuildInputs = [ $5 ];

  installPhase = ''
    $0
  '';
}]],
  },
  {
    'packagesmulti',
    'packages attrset across forAllSystems',
    [[
packages = forAllSystems (system:
  let
    pkgs = nixpkgs.legacyPackages.\${system};
  in {
    default = pkgs.callPackage ${1:./default.nix} { };
  });]],
  },

  -- apps
  {
    'app',
    'apps.default running a package binary',
    [[
apps.default = {
  type = "app";
  program = "\${self.packages.\${system}.default}/bin/$1";
};$0]],
  },

  -- overlays
  {
    'overlay',
    'overlays.default = final: prev: { ... }',
    [[
overlays.default = final: prev: {
  $0
};]],
  },
  {
    'overlaypkg',
    'Overlay adding a single package',
    [[
overlays.default = final: prev: {
  ${1:name} = final.callPackage ${2:./pkgs/name.nix} { };
};$0]],
  },

  -- NixOS / home-manager configs
  {
    'nixosmodule',
    'nixosModules.default with options/config',
    [[
nixosModules.default = { config, lib, pkgs, ... }:
  {
    options = {
      $1
    };

    config = {
      $0
    };
  };]],
  },
  {
    'nixossystem',
    'nixosConfigurations.<host> = nixpkgs.lib.nixosSystem { ... }',
    [[
nixosConfigurations.${1:hostname} = nixpkgs.lib.nixosSystem {
  system = "${2:x86_64-linux}";
  modules = [
    $0
  ];
};]],
  },
  {
    'hmconfig',
    'homeConfigurations.<user> = home-manager.lib.homeManagerConfiguration { ... }',
    [[
homeConfigurations.${1:user} = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.${2:x86_64-linux};
  modules = [
    $0
  ];
};]],
  },

  -- checks / formatter / templates
  {
    'checks',
    'checks attrset across forAllSystems',
    [[
checks = forAllSystems (system:
  let
    pkgs = nixpkgs.legacyPackages.\${system};
  in {
    $0
  });]],
  },
  {
    'formatter',
    'formatter output using nixfmt-rfc-style',
    [[formatter = forAllSystems (system: nixpkgs.legacyPackages.\${system}.nixfmt-rfc-style);$0]],
  },
  {
    'template',
    'templates.default = { path; description; }',
    [[
templates.default = {
  path = ${1:./.};
  description = "$2";
};$0]],
  },

  -- misc
  {
    'mkshellsimple',
    'Inline pkgs.mkShell { buildInputs = [ ... ]; }',
    [[
pkgs.mkShell {
  buildInputs = [ $1 ];
}$0]],
  },
  {
    'selfrev',
    'version = self.rev or "dirty"; pattern',
    [[version = self.rev or "dirty";$0]],
  },
}

local snippets = {}
for _, d in ipairs(defs) do
  table.insert(snippets, parse({ trig = d[1], name = d[1], dscr = d[2] }, d[3]))
end

local autosnippets = {}

return snippets, autosnippets
