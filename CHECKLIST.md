# Deployment checklist

Manual steps needed when setting up this flake on a new NixOS machine, or after
a fresh install. One-time items are marked; repeat the rest each time you deploy.

---

## Prerequisites (one-time per machine)

- [ ] NixOS installed with `nix.settings.experimental-features = [ "nix-command" "flakes" ]`
- [ ] `git clone ssh://git@10.10.0.101/v/dotfiles_nix.git ~/dotfiles-nix && cd ~/dotfiles-nix`
- [ ] Generate/update `hosts/<host>/hardware-configuration.nix`:
      `sudo nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix`
- [ ] Review diffs and commit hardware config

## Deployment flow (each time)

- [ ] `git pull` (or review pending changes)
- [ ] `nix flake check` — verify all packages, apps, and checks build
- [ ] Pre-deploy snapshot (optional, but recommended before system changes):
      `nix run .#capture-host`
- [ ] Deploy: `nix run .#deploy-host -- --host <name>`
      (builds → `sudo nixos-rebuild switch` → home-manager → sets shell)
- [ ] Verify: `nixos-rebuild list-generations` — confirm the new generation is active

## Secrets provisioning (one-time per machine)

These files live outside the repo (like `/etc/wireguard/`).

### WireGuard
- [ ] Create `/etc/wireguard/wg1.conf` (root 0600, complete wg-quick config)
- [ ] Create `/etc/wireguard/wg3.conf` (root 0600, optional on-demand interface)
- [ ] Enable in config: `dotfiles.wireguard.enable = true`

### Forgejo Actions runner (`home` host only)
- [ ] Create a registration token in Forgejo admin → Actions → Runners
      (admin privilege required — any Forgejo admin can generate one), then:
      ```
      sudo mkdir -p /etc/forgejo-runner
      sudo chmod 0700 /etc/forgejo-runner
      echo 'TOKEN=<paste>' | sudo tee /etc/forgejo-runner/registration-token.env
      sudo chmod 0600 /etc/forgejo-runner/registration-token.env
      ```
- [ ] Deploy the flake first (creates the `forgejo-runner` system user):
      `sudo nixos-rebuild switch --flake .#home`
      (The runner service will fail to start — that's expected, the SSH key isn't
      in place yet.)
- [ ] Generate an SSH deploy key (read-only, no passphrase) for flake input fetching:
      ```
      ssh-keygen -t ed25519 -f /tmp/ci_key -N ""
      sudo mkdir -p /var/lib/forgejo-runner/.ssh
      sudo cp /tmp/ci_key /var/lib/forgejo-runner/.ssh/id_ed25519
      sudo chmod 0700 /var/lib/forgejo-runner/.ssh
      sudo chmod 0600 /var/lib/forgejo-runner/.ssh/id_ed25519
      sudo chown -R forgejo-runner:forgejo-runner /var/lib/forgejo-runner/.ssh
      ```
- [ ] Register the public key (`/tmp/ci_key.pub`) on Forgejo as a **deploy
      key** with **read-only** access to `v/llama-server` and `v/opencode-mcp-tools`
      (use each repo's Settings → Deploy keys — not a user key — to scope per-repo)
- [ ] Clean up the temporary key files:
      `rm -f /tmp/ci_key /tmp/ci_key.pub`
- [ ] Add the Forgejo host key to the runner's known_hosts:
      `sudo -u forgejo-runner bash -c 'ssh-keyscan -H 10.10.0.101 >> /var/lib/forgejo-runner/.ssh/known_hosts 2>/dev/null || true'`
- [ ] Start the runner: `sudo systemctl start gitea-runner-home`
- [ ] Verify: `systemctl status gitea-runner-home` and check Forgejo admin → Actions

## After a fresh NixOS install

- [ ] All prerequisites above
- [ ] All secrets above
- [ ] First home-manager activation (home-manager not on PATH yet):
      `nix run github:nix-community/home-manager -- switch -b backup --flake .#v`
- [ ] If zsh not recognized as a login shell, add to `/etc/shells`:
      `command -v zsh | sudo tee -a /etc/shells`
- [ ] `nix run .#set-default-shell`

## Verifying the CI runner (post-deployment)

- [ ] Push a commit and confirm the CI workflow runs in Forgejo
- [ ] Check job logs for both `checks` and `system-builds` jobs