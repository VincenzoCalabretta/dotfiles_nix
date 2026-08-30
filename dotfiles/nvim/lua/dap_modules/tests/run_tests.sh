#!/usr/bin/env bash
# Run the dap_modules unit test suite with plenary.nvim (already a lazy.nvim
# dependency of this config -- see plugins/telescope.lua). Exit code is
# nonzero if any test fails.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

nvim --headless --noplugin -u "${tests_dir}/minimal_init.lua" \
  -c "PlenaryBustedDirectory ${tests_dir} { minimal_init = '${tests_dir}/minimal_init.lua' }"
