# Deploying the `home` host

This directory is the version-controlled NixOS configuration for the desktop
host named `nixos`. The flake output is `nixosConfigurations.home`; invoke it
with `#home`.

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
nix run ~/dotfiles-nix#home-build
```

This is the recommended check before deployment. The resulting `result`
symlink points to the built system closure.

## Deploy the full stack (NixOS + home-manager + shell)

```sh
nix run ~/dotfiles-nix#deploy-host -- --host home
```

This builds and switches the system configuration, activates the home-manager
profile, and sets zsh as the login shell — all in one invocation.

Alternatively, deploy the system configuration alone:

```sh
nix run ~/dotfiles-nix#home-switch
```

After switching, verify the active generation:

```sh
readlink -f /run/current-system
nixos-rebuild list-generations
```

## Snapshot the live config into the repo

```sh
nix run ~/dotfiles-nix#capture-host -- --host home
```

Copies `/etc/nixos/{configuration,hardware-configuration}.nix` into this
directory with absolute imports rewritten to repo-relative paths. Review and
commit the result.

## Roll back

For a problem discovered immediately after switching:

```sh
sudo nixos-rebuild switch --rollback
```

For a generation that prevents a successful boot, select an earlier entry from
the systemd-boot menu. Once booted, make the rollback persistent with the same
command above, then fix and commit the configuration before trying again.
