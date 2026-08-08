#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: capture-host [--host <name>] [--generate-hardware] [--full-build] [--yes]

Copy the live /etc/nixos/* configuration into this repo under hosts/<name>/,
rewriting absolute imports to repo-relative paths for portability.

Options:
  --host <name>        Target host directory under hosts/ (default: hostname mapped)
  --generate-hardware  Run nixos-generate-config and use its output
  --full-build         Run nixos-rebuild build to verify the rewritten config
  --yes                Skip confirmation prompt

Hostname mapping: nixos → home, server → server (otherwise literal).
EOF
  exit 1
}

HOST=""
GENERATE_HW=""
FULL_BUILD=""
YES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)              HOST="$2";         shift 2 ;;
    --generate-hardware) GENERATE_HW=1;      shift ;;
    --full-build)        FULL_BUILD=1;       shift ;;
    --yes)               YES=1;             shift ;;
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
  echo "Run this script from within the dotfiles-nix checkout."
  exit 1
}

TARGET_DIR="${REPO_ROOT}/hosts/${HOST}"
mkdir -p "${TARGET_DIR}"

# ── Capture configuration.nix ──────────────────────────────────────────────
SRC_CONFIG="/etc/nixos/configuration.nix"
DST_CONFIG="${TARGET_DIR}/configuration.nix"

if [[ ! -f "${SRC_CONFIG}" ]]; then
  echo "Error: ${SRC_CONFIG} not found. Are you on a NixOS system?"
  exit 1
fi

# Copy with portability rewrites
{
  echo "# Captured from host '${HOST}' on $(date -Iseconds)"
  echo "# Generation: $(readlink -f /run/current-system 2>/dev/null || echo 'unknown')"
  echo "# Rewritten for repo-relative imports. Review before committing."
  echo ""
  sed -E \
    -e '/^[[:space:]]*\/\/|^[[:space:]]*#/d' \
    -e "s|/home/[a-zA-Z0-9_.-]+/dotfiles-nix/modules/|../../modules/|g" \
    -e "s|/home/[a-zA-Z0-9_.-]+/dotfiles-nix/|../../|g" \
    "${SRC_CONFIG}"
} > "${DST_CONFIG}"

echo "[capture-host] Written ${DST_CONFIG}"

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