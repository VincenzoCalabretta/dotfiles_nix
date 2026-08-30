#!/usr/bin/env bash
# Generates a self-contained line-coverage HTML report for dap_modules'
# own Lua files (dap_modules/*.lua + bazel_picker.lua) by running the same
# plenary test suite as run_tests.sh with coverage.lua's debug.sethook
# instrumentation enabled.
#
# Unlike run_tests.sh, this is not meant to run on every save -- line hooks
# plus jit.off() noticeably slow the whole suite down. Run it when you
# actually want the report.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dap_modules_dir="$(dirname "$tests_dir")"
lua_dir="$(dirname "$dap_modules_dir")"
report_dir="$dap_modules_dir/coverage"
data_dir="$(mktemp -d)"
trap 'rm -rf "$data_dir"' EXIT

mkdir -p "$report_dir"

echo "Running tests with coverage instrumentation..."
DAP_MODULES_COVERAGE_DIR="$data_dir" nvim --headless --noplugin -u "${tests_dir}/minimal_init.lua" \
  -c "PlenaryBustedDirectory ${tests_dir} { minimal_init = '${tests_dir}/minimal_init.lua' }" \
  || echo "(some tests failed -- the coverage report will still be generated)"

echo "Rendering HTML report..."
nvim -l "${tests_dir}/render_coverage.lua" \
  "$data_dir" "$report_dir/index.html" \
  "$dap_modules_dir" "$lua_dir/bazel_picker.lua"

echo "Coverage report: $report_dir/index.html"
