{ pkgs, ... }:

# TLA+ tooling: SANY (parser/type-checker), TLC (model checker), tlatex,
# and pcal (the PlusCal-to-TLA+ translator) -- PlusCal has no separate
# toolchain, it's always translated into a .tla file's comment block.
{
  home.packages = [ pkgs.tlaplus ];
}
