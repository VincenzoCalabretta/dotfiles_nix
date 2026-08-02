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

    # LSPs / formatters listed in plugins/lsp.lua ensure_installed
    lua-language-server
    basedpyright
    ruff
    stylua
    rust-analyzer
    clang-tools     # provides clangd
  ];

  xdg.configFile."nvim".source = ../dotfiles/nvim;
}
