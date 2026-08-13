#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: capture-host [--host <name>] [--generate-hardware] [--full-build] [--yes]
                     [--base-repo-name <name>]

Copy the live /etc/nixos/* configuration into this repo under hosts/<name>/,
rewriting absolute imports to repo-relative paths for portability.

Options:
  --host <name>           Target host directory under hosts/ (default: hostname mapped)
  --generate-hardware     Run nixos-generate-config and use its output
  --full-build            Run nixos-rebuild build to verify the rewritten config
  --yes                   Skip confirmation prompt
  --base-repo-name <name> Local clone dirname of the public dotfiles-nix base
                           repo (default: dotfiles-nix). Used to recognize
                           imports of ITS modules and rewrite them
                           differently from imports of this repo's own
                           modules — see below.

Hostname mapping: nixos → home, server → server (otherwise literal).

Two kinds of absolute imports get rewritten differently:
  - Imports of THIS repo's own modules (matched against the checkout this
    script is running in) become repo-relative: ../../modules/foo.nix
  - Imports of the base repo's modules (matched against --base-repo-name)
    become inputs.dotfiles.nixosModules.foo — but ONLY for module names it
    actually exports (see KNOWN_BASE_MODULES below). Anything else is left
    as an absolute path with a warning: it's either a private/unexported
    module (e.g. hardware.nix) that has no flake-input equivalent, or a name
    this script doesn't recognize, and either way guessing would be wrong.
    A config using this rewrite needs \`{ inputs, ... }:\` in its function
    header and \`specialArgs = { inherit inputs; }\` wired up in flake.nix —
    this script reminds you, it doesn't do that part for you.
EOF
  exit 1
}

HOST=""
GENERATE_HW=""
FULL_BUILD=""
YES=""
BASE_REPO_NAME="dotfiles-nix"

# Module names nixosModules.* actually exports from the base repo's
# flake.nix — keep in sync with it. Anything else found under
# .../<BASE_REPO_NAME>/modules/*.nix is left untouched with a warning
# instead of guessing at a nixosModules attribute that doesn't exist.
KNOWN_BASE_MODULES="nixos-base|wireguard|forgejo-runner|nvidia|wireshark|netdebug"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)              HOST="$2";            shift 2 ;;
    --generate-hardware) GENERATE_HW=1;         shift ;;
    --full-build)        FULL_BUILD=1;          shift ;;
    --yes)               YES=1;                shift ;;
    --base-repo-name)    BASE_REPO_NAME="$2";   shift 2 ;;
    -h|--help)           usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Detect host
if [[ -z "${HOST}" ]]; then
  HOSTNAME="$(hostname)"
  case "${HOSTNAME}" in
    nixos)  HOST="home" ;;
    server) HOST="server" ;;
    *)      HOST="${HOSTNAME}" ;;
  esac
fi

# Find repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository (needed to find repo root)."
  echo "Run this script from within your dotfiles checkout."
  exit 1
}
REPO_BASENAME="$(basename "${REPO_ROOT}")"

TARGET_DIR="${REPO_ROOT}/hosts/${HOST}"
mkdir -p "${TARGET_DIR}"

# ── Capture configuration.nix ──────────────────────────────────────────────
SRC_CONFIG="/etc/nixos/configuration.nix"
DST_CONFIG="${TARGET_DIR}/configuration.nix"

if [[ ! -f "${SRC_CONFIG}" ]]; then
  echo "Error: ${SRC_CONFIG} not found. Are you on a NixOS system?"
  exit 1
fi

# Copy with portability rewrites. Order matters: the self-repo rewrite runs
# first and only matches this checkout's own directory name, so if
# REPO_BASENAME happens to equal BASE_REPO_NAME (i.e. you're capturing
# directly into the base repo itself) it wins outright and the base-repo
# rewrite below finds nothing left to match — the old single-repo behavior,
# unchanged. Otherwise the base-repo rewrite handles imports of that
# separate checkout.
{
  echo "# Captured from host '${HOST}' on $(date -Iseconds)"
  echo "# Generation: $(readlink -f /run/current-system 2>/dev/null || echo 'unknown')"
  echo "# Rewritten for repo-relative imports. Review before committing."
  echo ""
  sed -E \
    -e '/^[[:space:]]*\/\/|^[[:space:]]*#/d' \
    -e "s|/home/[a-zA-Z0-9_.-]+/${REPO_BASENAME}/modules/|../../modules/|g" \
    -e "s|/home/[a-zA-Z0-9_.-]+/${REPO_BASENAME}/|../../|g" \
    -e "s#/home/[a-zA-Z0-9_.-]+/${BASE_REPO_NAME}/modules/(${KNOWN_BASE_MODULES})\.nix#inputs.dotfiles.nixosModules.\1#g" \
    "${SRC_CONFIG}"
} > "${DST_CONFIG}"

echo "[capture-host] Written ${DST_CONFIG}"

if grep -q 'inputs\.dotfiles\.nixosModules\.' "${DST_CONFIG}"; then
  echo "[capture-host] Rewrote one or more imports to inputs.dotfiles.nixosModules.* —"
  echo "  make sure ${DST_CONFIG} takes '{ inputs, ... }:' and that flake.nix passes"
  echo "  specialArgs = { inherit inputs; } to this host's nixosSystem call."
fi

if grep -E -q "/home/[a-zA-Z0-9_.-]+/${BASE_REPO_NAME}/modules/" "${DST_CONFIG}"; then
  echo "[capture-host] Warning: ${DST_CONFIG} still has an absolute import under"
  echo "  .../${BASE_REPO_NAME}/modules/ that wasn't recognized (not in KNOWN_BASE_MODULES)."
  echo "  Either it's private/unexported (no nixosModules.* equivalent — leave it"
  echo "  as-is or copy it in locally) or this script's module list is stale."
  grep -nE "/home/[a-zA-Z0-9_.-]+/${BASE_REPO_NAME}/modules/" "${DST_CONFIG}" || true
fi

# ── Capture hardware-configuration.nix ─────────────────────────────────────
if [[ -n "${GENERATE_HW:-}" ]]; then
  echo "[capture-host] Generating hardware config via nixos-generate-config …"
  HW_CONTENT="$(sudo nixos-generate-config --show-hardware-config 2>/dev/null)" || {
    echo "Error: nixos-generate-config failed."
    exit 1
  }
  echo "${HW_CONTENT}" > "${TARGET_DIR}/hardware-configuration.nix"
  echo "[capture-host] Written ${TARGET_DIR}/hardware-configuration.nix (generated)"
elif [[ -f "/etc/nixos/hardware-configuration.nix" ]]; then
  cp "/etc/nixos/hardware-configuration.nix" "${TARGET_DIR}/hardware-configuration.nix"
  echo "[capture-host] Written ${TARGET_DIR}/hardware-configuration.nix (copied)"
else
  echo "[capture-host] Warning: /etc/nixos/hardware-configuration.nix not found; not copied."
fi

# ── Secret guardrail ───────────────────────────────────────────────────────
# Only check the files we just wrote, not existing READMEs or other content.
for f in "${DST_CONFIG}" "${TARGET_DIR}/hardware-configuration.nix"; do
  if [[ -f "$f" ]] && grep -q '/etc/wireguard/' "$f" 2>/dev/null; then
    echo "Error: ${f} references /etc/wireguard/ paths."
    echo "Secrets must remain outside the repository. Remove those references first."
    # Don't leave the offending file(s) on disk — the guardrail should mean
    # "nothing was written", not "something was written, then complained about".
    rm -f "${DST_CONFIG}" "${TARGET_DIR}/hardware-configuration.nix"
    exit 1
  fi
done

# ── Verification ───────────────────────────────────────────────────────────
echo "[capture-host] Running eval sanity check …"
if nix eval "${REPO_ROOT}#nixosConfigurations.${HOST}.config.system.stateVersion" 2>/dev/null; then
  echo "[capture-host] Eval check passed."
else
  echo "[capture-host] Warning: eval check failed. The rewritten config may have issues."
  echo "  Review the diff and test manually: nixos-rebuild build --flake ${REPO_ROOT}#${HOST}"
fi

if [[ -n "${FULL_BUILD:-}" ]]; then
  echo "[capture-host] Running full build verification …"
  nixos-rebuild build --flake "${REPO_ROOT}#${HOST}" && \
    echo "[capture-host] Build check passed."
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "[capture-host] === Summary ==="
echo "  Host:      ${HOST}"
echo "  Directory: ${TARGET_DIR}"
echo ""
echo "Review the diff before committing:"
echo "  git diff --stat"
echo "  git diff ${TARGET_DIR}"
echo ""
echo "Commit when satisfied:"
echo "  git add hosts/${HOST} && git commit -m 'capture host ${HOST} config'"
