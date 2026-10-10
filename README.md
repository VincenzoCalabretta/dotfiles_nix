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
