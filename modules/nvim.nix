{ pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim

    # Build deps for lazy.nvim / telescope-fzf-native / treesitter
    gcc
    gnumake
    cmake
    tree-sitter
    nodejs
    unzip
    git

    # Runtime tools used by plugins
    ripgrep
    fd

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
