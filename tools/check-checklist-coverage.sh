#!/usr/bin/env bash
# Every CHECKLIST.md checkbox item must be classified so it can't silently
# go untested: <!-- manual --> (can't be automated — external systems, real
# hardware, human judgment), <!-- ci:<job> --> (already proven by an
# existing CI job/check), or <!-- test:<id> --> (proven by an automated
# test in this repo, e.g. tests/checklist-vm.nix).
set -euo pipefail

FILE="${1:-CHECKLIST.md}"
fail=0

while IFS= read -r line; do
  if [[ "$line" =~ ^-\ \[[\ x]\] ]]; then
    if [[ "$line" != *"<!-- manual"* && "$line" != *"<!-- ci:"* && "$line" != *"<!-- test:"* ]]; then
      echo "Unmarked checklist item (needs <!-- manual -->, <!-- ci:... -->, or <!-- test:... -->):"
      echo "  $line"
      fail=1
    fi
  fi
done < "$FILE"

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "Every CHECKLIST.md item must be classified: manual/external, already"
  echo "proven by an existing CI job, or proven by a new automated test."
  exit 1
fi

echo "OK: every CHECKLIST.md item is classified."
