#!/usr/bin/env bash
set -euo pipefail

FLAKE=""
HOST=""
SKIP_BUILD=""
SKIP_HOME=""
NO_SHELL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flake)   FLAKE="$2";   shift 2 ;;
    --host)    HOST="$2";    shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --skip-home)  SKIP_HOME=1;  shift ;;
    --no-shell)   NO_SHELL=1;   shift ;;
    *) echo "Usage: deploy-host --flake <path> --host <name> [--skip-build] [--skip-home] [--no-shell]"; exit 1 ;;
  esac
done

: "${FLAKE:?--flake <path> required}"
: "${HOST:?--host <name> required}"

if [[ -z "${SKIP_BUILD:-}" ]]; then
  echo "[deploy-host] Building system config for host '${HOST}' …"
  nixos-rebuild build --flake "${FLAKE}#${HOST}"
fi

echo "[deploy-host] Switching system config for host '${HOST}' …"
sudo nixos-rebuild switch --flake "${FLAKE}#${HOST}"

if [[ -z "${SKIP_HOME:-}" ]]; then
  echo "[deploy-host] Activating home-manager …"
  nix run "${FLAKE}#activate" || echo "[deploy-host] home-manager not yet deployed (skip with --skip-home)"
fi

if [[ -z "${NO_SHELL:-}" ]]; then
  if [[ "${SHELL}" != *zsh ]]; then
    echo "[deploy-host] Setting default shell to zsh …"
    nix run "${FLAKE}#set-default-shell" || true
  fi
fi

echo "[deploy-host] Done."