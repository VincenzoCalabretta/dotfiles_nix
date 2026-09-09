{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.nvim.compilerExplorer;
  compiler-explorer = pkgs.callPackage ../packages/compiler-explorer.nix { };
in
{
  options.dotfiles.nvim.compilerExplorer = {
    enable = lib.mkEnableOption "the Compiler Explorer Neovim client and local user service";

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString cfg.port}";
      description = "Compiler Explorer API base URL used by compiler-explorer.nvim.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 10240;
      description = "Loopback port exposed by the Compiler Explorer user socket.";
    };

    idleTimeoutSec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds without an HTTP request before the user service exits.";
    };
  };

  config = {
    home.packages = with pkgs; [
    neovim

    # Build deps for lazy.nvim / telescope-fzf-native / treesitter.
    # gcc, gnumake, git, unzip are shared (see home.nix).
    cmake
    tree-sitter
    nodejs

    # peek.nvim: builds its Deno-based preview server (build step in
    # plugins/peek.lua) and `app = "browser"` still shells out to the
    # `deno` binary at runtime to serve the preview.
    deno

    # ripgrep + fd are shared (see home.nix).

    # GDB + bundled pretty-printer scripts in dotfiles/nvim/gdb/
    gdb

    # GNU Global (gtags/global): whole-tree, config-independent cross-reference
    # fallback for gd/gr when clangd has no client attached or returns no
    # results (e.g. symbol lives in a file outside compile_commands.json).
    # DB lifecycle is managed by lua/gtags_db.lua (vim-gutentags' only
    # GNU Global backend, gtags_cscope, hard-requires :cscope, which Neovim
    # doesn't implement); queried directly via the `global` CLI from
    # lua/lsp_fallback.lua.
    global

    # LSPs / formatters listed in plugins/lsp.lua ensure_installed
    lua-language-server
    basedpyright
    ruff
    stylua
    rust-analyzer
    clang-tools     # provides clangd
    nixd            # Nix LSP; also used by opencode (modules/opencode.nix)

    # MLIR / TableGen LSPs (mlir-lsp-server, tblgen-lsp-server). Not
    # mason-managed: mason has no MLIR package, and building mlir-lsp-server
    # from source is a full LLVM/MLIR build. llvmPackages.mlir ships
    # prebuilt tool binaries and has a cached substitute on cache.nixos.org
    # for the pinned nixpkgs revision, so this doesn't compile locally.
    # Only understands MLIR's built-in dialects -- a downstream project with
    # custom dialects needs its own project-built mlir-lsp-server for full
    # diagnostics on its ops.
    llvmPackages.mlir

    # Bazel/Starlark LSP (BUILD, BUILD.bazel, WORKSPACE, *.bzl -- Neovim's
    # built-in filetype detection maps all of these to 'bzl'). Not
    # mason-managed: mason has no Starlark package.
    starpls
    ];

    xdg.configFile."nvim".source = ../dotfiles/nvim;

    home.sessionVariables = lib.mkIf cfg.enable {
      COMPILER_EXPLORER_URL = cfg.url;
    };

    xdg.configFile."compiler-explorer-nvim/url" = lib.mkIf cfg.enable {
      text = cfg.url;
    };

    # Give Lazy an external Nix store directory. This avoids a first-run
    # network clone and keeps Lazy from trying to rewrite the read-only
    # lockfile deployed with the Neovim configuration.
    xdg.configFile."compiler-explorer-nvim/plugin-path" = lib.mkIf cfg.enable {
      text = toString pkgs.vimPlugins.compiler-explorer-nvim;
    };

    systemd.user.sockets.compiler-explorer = lib.mkIf cfg.enable {
      Unit.Description = "Compiler Explorer activation socket";
      Socket = {
        ListenStream = "127.0.0.1:${toString cfg.port}";
        NoDelay = true;
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    # This intentionally runs as the Home Manager user. Project-aware
    # compilation needs read access to compile_commands.json include paths,
    # including CMake trees and Bazel execroots under the user's home.
    systemd.user.services.compiler-explorer = lib.mkIf cfg.enable {
      Unit = {
        Description = "Self-hosted Compiler Explorer";
        Requires = [ "compiler-explorer.socket" ];
        After = [ "compiler-explorer.socket" ];
      };
      Service = {
        ExecStart = lib.getExe compiler-explorer;
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "IDLE_TIMEOUT=${toString cfg.idleTimeoutSec}"
        ];
        Restart = "on-failure";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        NoNewPrivileges = true;
        UMask = "0077";
        CapabilityBoundingSet = "";
        SystemCallArchitectures = "native";
      };
    };
  };
}
