# Deploying the `server` host

Minimal NixOS configuration for a headless server (no display server, no GPU
drivers). Shares the same home-manager user profile via `flake.nix`.

## Before deploying

Review the changes and ensure all configuration files are tracked by Git:

```sh
cd ~/dotfiles-nix
git status
nix flake check --no-build
```

Generate a real `hardware-configuration.nix` on the target machine:

```sh
ssh server sudo nixos-generate-config --show-hardware-config
```

Replace the placeholder entries in `hosts/server/hardware-configuration.nix`
with the output. Do not place secrets in this repository: the WireGuard module
reads its private configuration from `/etc/wireguard/`.

## Build without changing the system

```sh
nix run ~/dotfiles-nix#server-build
```

## Deploy the full stack (NixOS + home-manager + shell)

```sh
nix run ~/dotfiles-nix#deploy-host -- --host server
```

This builds and switches the system configuration, activates the home-manager
profile, and sets zsh as the login shell — all in one invocation (the home-manager
activation runs on the target, not over SSH, so use it only locally).

Alternatively, deploy the system configuration alone via the existing app:

```sh
nix run ~/dotfiles-nix#server-switch
```

## Snapshot the live config into the repo

```sh
nix run ~/dotfiles-nix#capture-host -- --host server
```

Copies `/etc/nixos/{configuration,hardware-configuration}.nix` into this
directory with absolute imports rewritten to repo-relative paths. Review and
commit the result.

## Roll back

```sh
sudo nixos-rebuild switch --rollback
```