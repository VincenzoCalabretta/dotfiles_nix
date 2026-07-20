{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lf
    # lfrc uses these external commands
    file
    unzip
    unrar
    p7zip
    gnutar
    gzip
    xz
    bzip2
    xdg-utils                    # xdg-open
    perlPackages.FileMimeInfo    # provides `mimeopen`
  ];

  xdg.configFile."lf".source = ../dotfiles/lf;
}
