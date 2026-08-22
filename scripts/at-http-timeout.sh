#!/usr/bin/env bash
# Negative acceptance test for the request timeout (speq-tms/speq-docs#59).
#
# The green suite cannot contain a test that is meant to fail, so the timeout
# case lives in `negative-suites/` and is asserted here: the run must end
# quickly, exit non-zero, and report a message naming the budget it blew —
# rather than hanging until the CI runner's hard limit.
set -euo pipefail

SPEQ="${SPEQ_BIN:-speq}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/test-repo-mode-jsonplaceholder"
ENV_NAME="${SPEQ_ENV:-ci}"
# Generous ceiling: the point is that the run is bounded at all, not that it is
# fast to the millisecond on a loaded CI runner.
MAX_SECONDS="${MAX_SECONDS:-60}"

workdir="$(mktemp -d)"
summary="$workdir/timeout-summary.json"
trap 'rm -rf "$workdir"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

started=$(date +%s)
set +e
# One file, not the whole directory: `negative-suites/` also holds the cases
# for the `error` status, which `scripts/at-error-status.sh` owns.
"$SPEQ" run --speq-root "$ROOT" --env "$ENV_NAME" \
  --test negative-suites/timeout_fails_fast.yaml \
  --report summary --output "$summary"
exit_code=$?
set -e
elapsed=$(( $(date +%s) - started ))

[ "$exit_code" -ne 0 ] || fail "a timed-out run must exit non-zero, got 0"
[ "$elapsed" -le "$MAX_SECONDS" ] || fail "run took ${elapsed}s, expected it to be bounded under ${MAX_SECONDS}s"
[ -f "$summary" ] || fail "no summary written at $summary"

python3 - "$summary" <<'PYEOF'
import json
import sys

summary = json.load(open(sys.argv[1]))
totals = summary["totals"]
# A request that never returned is an `error`, not a `failed` expectation --
# there was no answer to judge (speq-tms/speq-docs#64).
assert totals.get("error") == 1, f"expected exactly one errored test, got {totals}"
assert totals.get("failed", 0) == 0, f"a timeout is not an assertion failure, got {totals}"
assert totals["passed"] == 0, f"nothing may pass in the negative suite, got {totals}"

messages = [t.get("message") or "" for t in summary["tests"]]
assert any("timeout: request exceeded 1ms budget" in m for m in messages), (
    f"expected a timeout message naming the 1ms budget, got {messages}"
)
PYEOF

echo "OK: the run failed fast in ${elapsed}s with a timeout naming its budget"
