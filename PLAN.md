# dotfiles-nix: CI + portable deploy tooling + self-hosted Forgejo runner

## Motivation

- Test in CI that the home-manager flake, both NixOS system configs (home + server),
  and the deploy utility scripts all work — every push.
- Add a one-command `deploy-host` that does from-zero to running-system in a single
  invocation (nixos-rebuild switch + home-manager switch + set shell).
- Add a `capture-host` tool that snapshots the live system's `/etc/nixos/*` into the
  repo, rewriting absolute paths to repo-relative imports so the result is portable
  and the repo becomes the single source of truth for full-system deployment.
- Run the CI on the desktop itself via a **Forgejo Actions runner** deployed from
  this flake, so builds benefit from a warm local `/nix/store` and no external
  CI infrastructure is needed.

## Files touched / created

### New files

| File | Purpose |
|------|---------|
| `modules/forgejo-runner.nix` | NixOS module deploying a Forgejo Actions runner via `services.gitea-actions-runner` on this machine |
| `tools/capture-host.sh` | Snapshot live `/etc/nixos/*` into `hosts/<name>/`, with portability rewrites |
| `tools/deploy-host.sh` | Single-stop deploy: nixos-rebuild switch → home-manager → set shell |
| `.forgejo/workflows/ci.yml` | Forgejo Actions CI workflow running on the self-hosted runner |

### Modified files

| File | Change |
|------|--------|
| `flake.nix` | Add `nixosModules.forgejo-runner`, `checks.*`, new apps/packages |
| `hosts/home/configuration.nix` | Import `forgejo-runner.nix` + enable |
| `README.md` | Runner setup, CI, capture-host, deploy-host docs |
| `hosts/home/README.md` | Reference new tooling |
| `hosts/server/README.md` | Reference new tooling |

## Implementation order

1. `modules/forgejo-runner.nix` + wire into `home` + expose in flake
2. `tools/capture-host.sh` + `tools/deploy-host.sh` + flake checks/apps
3. `nix flake check` locally to verify
4. `.forgejo/workflows/ci.yml`
5. Documentation updates
6. Provision secrets and run first CI

---

## 1. Forgejo runner module (`modules/forgejo-runner.nix`)

Uses nixpkgs' `services.gitea-actions-runner` (confirmed at pinned nixpkgs rev
b7c2ada9 — path `nixos/modules/services/continuous-integration/gitea-actions-runner.nix`).

Key design decisions:

- **Host execution**: labels `["self-hosted:host"]` — jobs run directly on the host
  without Docker/Podman, using the machine's own nix, git, store, and caches.
- **Real system user**: overrides the module's `DynamicUser=true` default with a
  stable `forgejo-runner` system user, so:
  - `~/.ssh/id_ed25519` (the deploy key for flake inputs) stays across restarts.
  - User name is resolvable at nix-daemon RPC time for `trusted-users`.
- **Registration token**: `tokenFile = "/etc/forgejo-runner/registration-token.env"`
  (an EnvironmentFile containing `TOKEN=...`), root-owned 0600, never enters the store.
- **Secrets outside the repo** (following the wireguard pattern):
  - Registration token → `/etc/forgejo-runner/registration-token.env`
  - SSH deploy key → `/var/lib/forgejo-runner/.ssh/id_ed25519`

Module exposes `dotfiles.forgejo-runner.enable` (and optional overrides for `url`,
`name`, `tokenFile`, `capacity`, `labels`). Wired as `nixosModules.forgejo-runner`.

Provisioning (one-time, manual):
```sh
# 1. Get a registration token from Forgejo admin → Actions
sudo mkdir -p /etc/forgejo-runner
sudo chmod 0700 /etc/forgejo-runner
echo 'TOKEN=<paste>' | sudo tee /etc/forgejo-runner/registration-token.env
sudo chmod 0600 /etc/forgejo-runner/registration-token.env

# 2. Generate SSH deploy key for flake input fetching
ssh-keygen -t ed25519 -f /tmp/ci_key -N ""
sudo mkdir -p /var/lib/forgejo-runner/.ssh
sudo mv /tmp/ci_key /var/lib/forgejo-runner/.ssh/id_ed25519
sudo chmod 0700 /var/lib/forgejo-runner/.ssh
sudo chmod 0600 /var/lib/forgejo-runner/.ssh/id_ed25519
sudo chown -R forgejo-runner:forgejo-runner /var/lib/forgejo-runner/.ssh

# 3. Register the public key on the Forgejo git user with read access to
#    v/llama-server and v/opencode-mcp-tools
echo "Add this to Forgejo → settings → SSH/GPG Keys:"
cat /tmp/ci_key.pub; rm -f /tmp/ci_key.pub

# 4. Deploy the runner
nix run .#home-switch
```

After switch: verify `systemctl status gitea-runner-home` and check the runner
appears in Forgejo → (org/settings?) → Actions → Runners.

---

## 2. Snapshot + deploy tooling + flake checks

### `capture-host` (`tools/capture-host.sh`)

```
nix run .#capture-host -- [--host <name>] [--full-build]
```

- Defaults host from `hostname` (with `nixos → home` mapping); `--host` overrides.
- Copies `/etc/nixos/configuration.nix` and `hardware-configuration.nix` into
  `hosts/<name>/`.
- **Portability rewrite**: transforms absolute imports
  (`/home/*/dotfiles-nix/modules/...`) to repo-relative (`../../modules/...`),
  keeps `./hardware-configuration.nix`. Prepends capture header with date
  and current system generation.
- Refuses to touch `/etc/wireguard/*` — secrets stay out of the repo.
- Eval-sanity: runs `nix eval .#nixosConfigurations.<host>.config.system.stateVersion`
  after rewrite; `--full-build` runs a real `nixos-rebuild build` to prove it.
- Prints `git diff --stat` + review instruction. Idempotent.

### `deploy-host` (`tools/deploy-host.sh`)

```
nix run .#deploy-host -- --host <name> [--skip-build] [--skip-home] [--no-shell]
```

1. `nixos-rebuild build --flake .#<host>` (verify before touching — skip with `--skip-build`)
2. `sudo nixos-rebuild switch --flake .#<host>`
3. `nix run .#activate` (home-manager activation — skip with `--skip-home`)
4. Ensure login shell is zsh (`nix run .#set-default-shell` — skip with `--no-shell`)

### Flake `checks`

```nix
checks.${system} = {
  home-manager-build = self.homeConfigurations."v".activationPackage;
  system-server-toplevel = self.nixosConfigurations.server.config.system.build.toplevel;
  system-home-toplevel   = self.nixosConfigurations.home.config.system.build.toplevel;
  deploy-tools = pkgs.symlinkJoin {
    name = "deploy-tools";
    paths = with self.packages.${system}; [ activate set-default-shell deploy-host capture-host ];
  };
};
```

All packages/apps/checks share derivations — `nix flake check` is the single
local + CI command.

---

## 3. CI workflow (`.forgejo/workflows/ci.yml`)

```yaml
runs-on: [self-hosted]
```

Because the runner IS this machine:
- No nix installation step (the host's own nix).
- No SSH setup (the runner user's `~/.ssh/id_ed25519` is provisioned once).
- No Forgejo secrets for CI — all auth lives on the machine, like `/etc/wireguard`.

Two jobs in parallel:
1. **checks** (fast): `nix flake check` + `home-manager build`
2. **system-builds** (heavy): toplevel builds for both hosts + smoke-test deploy apps

---

## 4. Documentation

- **README.md**: Layout update (`tools/`, `.forgejo/`, `nixosModules.forgejo-runner`),
  new "CI" section, runner setup guide, capture-host/deploy-host usage.
- **hosts/*/README.md**: reference deploy-host and capture-host.