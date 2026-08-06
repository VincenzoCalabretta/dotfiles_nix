{ pkgs, ... }:

# Rust compiler and package manager for local development.
{
  home.packages = with pkgs; [
    rustc
    cargo
  ];
}
