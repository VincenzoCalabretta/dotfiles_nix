# Deploying the `nixos` host

This directory is the version-controlled NixOS configuration for the host
named `nixos`. It replaces an ad-hoc `/etc/nixos/configuration.nix` workflow;
the flake output is `nixosConfigurations.nixos`.

## Before deploying

Review the changes and ensure all configuration files are tracked by Git:

```sh
cd ~/dotfiles-nix
git status
nix flake check --no-build
```

`hardware-configuration.nix` describes this machine's disks, boot partition,
and CPU. Regenerate it only after a hardware or partition-layout change, then
review and commit the resulting diff. Do not place secrets in this repository:
the WireGuard module reads its private configuration from `/etc/wireguard/`.

## Build without changing the system

Build the next system generation and leave the currently booted configuration
untouched:

```sh
nix run ~/dotfiles-nix#nixos-build
```

This is the recommended check before deployment. The resulting `result`
symlink points to the built system closure.

## Deploy the configuration

Activate a new system generation now and make it the boot default:

```sh
nix run ~/dotfiles-nix#nixos-switch
```

The app invokes `sudo nixos-rebuild switch --flake ~/dotfiles-nix#nixos`.
It prompts for administrator authentication and is the only deployment step;
ordinary flake evaluation and `nixos-build` do not modify the running system.

After switching, verify the active generation:

```sh
readlink -f /run/current-system
nixos-rebuild list-generations
```

## Roll back

For a problem discovered immediately after switching:

```sh
sudo nixos-rebuild switch --rollback
```

For a generation that prevents a successful boot, select an earlier entry from
the systemd-boot menu. Once booted, make the rollback persistent with the same
command above, then fix and commit the configuration before trying again.
