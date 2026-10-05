#!/usr/bin/env bash
# Run Maestro tests with the variables in .env.
#
# Usage (from anywhere):
#   scripts/run_tests.sh                          # all tests in .maestro/tests
#   scripts/run_tests.sh --include-tags=smoke     # smoke suite
#   scripts/run_tests.sh .maestro/tests/search    # one domain (or a single file)
#
# Every run writes to artifacts/maestro/<run-id>/ (debug output + report).
# Override the run id with RUN_ID=<id> scripts/run_tests.sh ...
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "error: .env not found. Create it with: cp .env.example .env" >&2
  exit 1
fi
# Export everything in .env; Maestro exposes MAESTRO_* shell variables to flows.
set -a
# shellcheck disable=SC1091
source .env
set +a

: "${MAESTRO_APP_ID:?MAESTRO_APP_ID must be set in .env}"

RUN_ID="${RUN_ID:-local-$(date +%Y%m%d-%H%M%S)}"
export MAESTRO_RUN_ID="$RUN_ID"
OUTPUT_DIR="artifacts/maestro/$RUN_ID"
REPORT_FORMAT="${REPORT_FORMAT:-JUNIT}"

# Default target is the whole workspace unless a path was passed.
has_target=false
for arg in "$@"; do
  [[ "$arg" != -* && -e "$arg" ]] && has_target=true
done
targets=()
$has_target || targets=(.maestro)

device_args=()
[[ -n "${DEVICE_ID:-}" ]] && device_args=(--device "$DEVICE_ID")

report_args=()
case "$REPORT_FORMAT" in
  JUNIT) report_args=(--format JUNIT --output "$OUTPUT_DIR/report.xml") ;;
  HTML|HTML-DETAILED) report_args=(--format "$REPORT_FORMAT" --output "$OUTPUT_DIR/report.html") ;;
esac

echo "run: $RUN_ID | app: $MAESTRO_APP_ID | platform: ${MAESTRO_PLATFORM:-unset} | device: ${DEVICE_ID:-auto}"
echo "output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"
maestro "${device_args[@]+"${device_args[@]}"}" test \
  --test-output-dir "$OUTPUT_DIR" \
  "${report_args[@]+"${report_args[@]}"}" \
  "$@" "${targets[@]+"${targets[@]}"}"
