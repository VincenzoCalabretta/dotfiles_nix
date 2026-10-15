# Redeploy

Run these commands after changing either `~/dotfiles_nix` or
`~/dotfiles_nix_personal`:

```bash
sudo nixos-rebuild switch \
  --flake /home/v/dotfiles_nix_personal#home \
  --override-input dotfiles path:/home/v/dotfiles_nix

nix run --override-input dotfiles path:/home/v/dotfiles_nix \
  /home/v/dotfiles_nix_personal#activate
```

The first command rebuilds and switches NixOS. The second activates the Home
Manager profile.

# Manual pages

The Home Manager base profile installs available `man` and `devman` outputs
for its packages, plus Linux and POSIX reference pages (`man-pages` and
`man-pages-posix`). It enables `man` and builds an index for `apropos` and
`man -k`.

Hosts importing `nixosModules.nixos-base` also enable system package manuals,
developer documentation, GNU Info pages, and the NixOS manual. Rebuild and
activate using the commands above to apply these settings.

For example, use `man 2 open` for Linux system calls, `man 3 printf` for C
library functions, and `man 1p ls` for the POSIX command reference. Packages
that do not ship manual pages still need their upstream documentation.
