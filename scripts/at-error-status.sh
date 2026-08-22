#!/usr/bin/env bash
# Acceptance test for the `error` status (speq-tms/speq-docs#64).
#
# One question separates `error` from `failed`: did the service answer?
# `negative-suites/` holds one of each, so a single run shows whether the
# runtime tells them apart:
#
#   * a port nothing is listening on     -> error  (no answer to judge)
#   * a request that outlives its budget -> error  (no answer to judge)
#   * a wrong expectation, live service  -> failed (the answer is wrong)
#
# All three exit non-zero, which is why none of them can live in `suites/`.
set -euo pipefail

SPEQ="${SPEQ_BIN:-speq}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$REPO/test-repo-mode-jsonplaceholder"
ENV_NAME="${SPEQ_ENV:-ci}"

# Run against a copy so the repository's own reports/ is left alone.
workdir="$(mktemp -d)"
run_root="$workdir/project"
summary="$workdir/error-status-summary.json"
trap 'rm -rf "$workdir"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

cp -R "$ROOT" "$run_root"
rm -rf "$run_root/reports"

set +e
"$SPEQ" run --speq-root "$run_root" --env "$ENV_NAME" --suite negative-suites \
  --report all --output "$summary" >"$workdir/run.out" 2>&1
exit_code=$?
set -e

[ "$exit_code" -ne 0 ] || { cat "$workdir/run.out"; fail "a run containing an error must exit non-zero"; }
[ -f "$summary" ] || { cat "$workdir/run.out"; fail "no summary written at $summary"; }

python3 - "$summary" <<'PYEOF'
import json
import sys

summary = json.load(open(sys.argv[1]))
totals = summary["totals"]
by_id = {t["id"]: t["status"] for t in summary["tests"]}

# No answer arrived, so there is nothing to call wrong.
assert by_id.get("http.status.unreachable-is-error") == "error", by_id
assert by_id.get("http.transport.timeout-fails-fast") == "error", by_id
# The service answered; the expectation was wrong.
assert by_id.get("http.status.wrong-expectation-is-failed") == "failed", by_id

assert totals.get("error") == 2, f"expected two errors, got {totals}"
assert totals.get("failed") == 1, f"expected one failure, got {totals}"
assert totals.get("passed") == 0, f"nothing may pass in the negative suite, got {totals}"

# The run's own status stays `failed`: the results contract admits only
# `passed` and `failed` there, and the distinction lives in the counters.
assert summary["status"] == "failed", summary["status"]
PYEOF

# Allure has its own vocabulary: a test that could not be judged is `broken`.
# Filing an error as `failed` would put a service that is not running in the
# same bucket as a service that answered wrongly.
python3 - "$run_root/reports/allure" <<'PYEOF'
import json
import pathlib
import sys

statuses = sorted(
    json.loads(p.read_text())["status"]
    for p in pathlib.Path(sys.argv[1]).glob("*-result.json")
)
assert statuses == ["broken", "broken", "failed"], statuses
PYEOF

echo "OK: error and failed are told apart in summary.json and in Allure"
