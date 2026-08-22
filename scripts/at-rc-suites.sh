#!/usr/bin/env bash
# Runs the examples that need runtime the released CLI does not have yet.
#
# The workflows install the released `speq`, so an example demonstrating an
# unreleased feature would turn the acceptance gate red until the release
# catches up. Those examples live in `rc-suites/`, outside `suitesDir`, and are
# run here against a locally built binary instead.
#
# This directory is temporary by construction. Everything in it belongs in
# `suites/` once the release that carries its feature ships.
set -euo pipefail

SPEQ="${SPEQ_BIN:-speq}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/test-repo-mode-jsonplaceholder"
ENV_NAME="${SPEQ_ENV:-ci}"

workdir="$(mktemp -d)"
summary="$workdir/rc-summary.json"
trap 'rm -rf "$workdir"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

"$SPEQ" run --speq-root "$ROOT" --env "$ENV_NAME" --suite rc-suites \
  --report summary --output "$summary" || fail "the rc-suites examples must pass on the RC binary"

python3 - "$summary" <<'PYEOF'
import json
import sys

summary = json.load(open(sys.argv[1]))
totals = summary["totals"]
assert totals["failed"] == 0, f"expected a green run, got {totals}"
assert totals["passed"] > 0, f"expected at least one example to run, got {totals}"
PYEOF

echo "OK: the rc-suites examples pass on this binary"
