# Deployment checklist

Manual steps needed when setting up this flake on a new NixOS machine, or after
a fresh install. One-time items are marked; repeat the rest each time you deploy.

Every item below is machine-classified in an inline comment:
`<!-- manual -->` (can't be automated — external systems, real hardware, human
judgment), `<!-- ci:<job> -->` (already proven by an existing CI job/check), or
`<!-- test:<id> -->` (proven by an automated test — see `tests/checklist-vm.nix`).
`tools/check-checklist-coverage.sh` fails CI if any item is missing a marker,
so a new step can't silently go untested.

---

## Prerequisites (one-time per machine)

- [ ] NixOS installed with `nix.settings.experimental-features = [ "nix-command" "flakes" ]` <!-- manual: fresh-install precondition -->
- [ ] `git clone ssh://git@10.10.0.101/v/dotfiles_nix.git ~/dotfiles-nix && cd ~/dotfiles-nix` <!-- manual: requires the real Forgejo instance + your registered SSH key -->
- [ ] Generate/update `hosts/<host>/hardware-configuration.nix`: <!-- manual: must run on real hardware; the committed file's validity is proven by ci:system-builds -->
      `sudo nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix`
- [ ] Review diffs and commit hardware config <!-- manual: human review -->

## Deployment flow (each time)

- [ ] `git pull` (or review pending changes) <!-- manual -->
- [ ] `nix flake check` — verify all packages, apps, and checks build <!-- ci:checks -->
- [ ] Pre-deploy snapshot (optional, but recommended before system changes): <!-- test:checklist-vm (capture-host rewrite + secret guardrail logic) -->
      `nix run .#capture-host`
- [ ] Deploy: `nix run .#deploy-host -- --host <name>` <!-- manual: switches the live system; its steps (build/switch/activate/set-shell) are each proven individually via ci:system-builds and ci:checks -->
      (builds → `sudo nixos-rebuild switch` → home-manager → sets shell)
- [ ] Verify: `nixos-rebuild list-generations` — confirm the new generation is active <!-- manual -->

## Secrets provisioning (one-time per machine)

These files live outside the repo (like `/etc/wireguard/`).

### WireGuard
- [ ] Create `/etc/wireguard/wg1.conf` (root 0600, complete wg-quick config) <!-- manual: real secret, provisioned out of band -->
- [ ] Create `/etc/wireguard/wg3.conf` (root 0600, optional on-demand interface) <!-- manual: real secret, provisioned out of band -->
- [ ] Enable in config: `dotfiles.wireguard.enable = true` <!-- test:checklist-vm (wg-quick-wg1 comes up from a stubbed conf) -->

### Forgejo Actions runner (`home` host only)
- [ ] Create a registration token in Forgejo admin → Actions → Runners <!-- manual: external UI action -->
      (admin privilege required — any Forgejo admin can generate one), then:
      ```
      sudo mkdir -p /etc/forgejo-runner
      sudo chmod 0700 /etc/forgejo-runner
      echo 'TOKEN=<paste>' | sudo tee /etc/forgejo-runner/registration-token.env
      sudo chmod 0600 /etc/forgejo-runner/registration-token.env
      ```
      <!-- test:checklist-vm (same commands run against a dummy token; asserts resulting perms) -->
- [ ] Deploy the flake first (creates the `forgejo-runner` system user): <!-- test:checklist-vm (module creates the user/group; asserted directly) -->
      `sudo nixos-rebuild switch --flake .#home`
      (The runner service will fail to start — that's expected, the SSH key isn't
      in place yet.)
- [ ] Generate an SSH deploy key (read-only, no passphrase) for flake input fetching: <!-- test:checklist-vm (same keygen command; asserts 0700/0600 perms + ownership) -->
      ```
      ssh-keygen -t ed25519 -f /tmp/ci_key -N ""
      sudo mkdir -p /var/lib/forgejo-runner/.ssh
      sudo cp /tmp/ci_key /var/lib/forgejo-runner/.ssh/id_ed25519
      sudo chmod 0700 /var/lib/forgejo-runner/.ssh
      sudo chmod 0600 /var/lib/forgejo-runner/.ssh/id_ed25519
      sudo chown -R forgejo-runner:forgejo-runner /var/lib/forgejo-runner/.ssh
      ```
- [ ] Register the public key (`/tmp/ci_key.pub`) on Forgejo as a **deploy <!-- manual: external UI action -->
      key** with **read-only** access to `v/llama-server` and `v/opencode-mcp-tools`
      (use each repo's Settings → Deploy keys — not a user key — to scope per-repo)
- [ ] Clean up the temporary key files: <!-- manual: trivial cleanup, not worth a dedicated test -->
      `rm -f /tmp/ci_key /tmp/ci_key.pub`
- [ ] Add the Forgejo host key to the runner's known_hosts: <!-- manual: needs a real route to the actual Forgejo host -->
      `sudo -u forgejo-runner bash -c 'ssh-keyscan -H 10.10.0.101 >> /var/lib/forgejo-runner/.ssh/known_hosts 2>/dev/null || true'`
- [ ] Start the runner: `sudo systemctl start gitea-runner-home` <!-- test:checklist-vm (unit starts and is configured as documented; real registration needs the live external Forgejo, see below) -->
- [ ] Verify: `systemctl status gitea-runner-home` and check Forgejo admin → Actions <!-- manual: needs the real, external Forgejo instance -->

## After a fresh NixOS install

- [ ] All prerequisites above <!-- manual -->
- [ ] All secrets above <!-- manual -->
- [ ] First home-manager activation (home-manager not on PATH yet): <!-- ci:checks (home-manager-build proves the activation package itself builds) -->
      `nix run github:nix-community/home-manager -- switch -b backup --flake .#v`
- [ ] If zsh not recognized as a login shell, add to `/etc/shells`: <!-- manual: mutates a real system file -->
      `command -v zsh | sudo tee -a /etc/shells`
- [ ] `nix run .#set-default-shell` <!-- ci:checks (deploy-tools check builds this package) -->

## Verifying the CI runner (post-deployment)

- [ ] Push a commit and confirm the CI workflow runs in Forgejo <!-- manual: needs the real, external Forgejo instance -->
- [ ] Check job logs for both `checks` and `system-builds` jobs <!-- manual: needs the real, external Forgejo instance -->
