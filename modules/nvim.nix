{ pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim

    # Build deps for lazy.nvim / telescope-fzf-native / treesitter.
    # gcc, gnumake, git, unzip are shared (see home.nix).
    cmake
    tree-sitter
    nodejs

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
  ];

  xdg.configFile."nvim".source = ../dotfiles/nvim;
}
