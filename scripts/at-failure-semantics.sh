#!/usr/bin/env bash
# Acceptance test for the failure semantics (speq-tms/speq-docs#63).
#
# The bug was that nothing ever stopped: one broken step produced an avalanche
# of derived failures, and the requests behind it kept flying at a live service
# after the scenario had already lost its meaning. Three cases in
# `negative-suites/` show the rule that replaced it, and this test reads what a
# developer reads -- summary.json and the Allure step list:
#
#   * a failure mid-body     -> the steps after it are `skipped`, not failed
#   * continueOnError: true  -> the step after a tolerated failure still runs
#   * a failure in setup     -> the body is skipped entirely
#
# and, in all three, cleanup ran anyway.
#
# All three tests fail on purpose, which is why none of them can live in
# `suites/`. They are tagged `failure-semantics` so this test selects only them.
set -euo pipefail

SPEQ="${SPEQ_BIN:-speq}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$REPO/test-repo-mode-jsonplaceholder"
ENV_NAME="${SPEQ_ENV:-ci}"

# Run against a copy so the repository's own reports/ is left alone.
workdir="$(mktemp -d)"
run_root="$workdir/project"
summary="$workdir/failure-semantics-summary.json"
trap 'rm -rf "$workdir"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

cp -R "$ROOT" "$run_root"
rm -rf "$run_root/reports"

set +e
"$SPEQ" run --speq-root "$run_root" --env "$ENV_NAME" --suite negative-suites \
  --tags failure-semantics --report all --output "$summary" >"$workdir/run.out" 2>&1
exit_code=$?
set -e

[ "$exit_code" -ne 0 ] || { cat "$workdir/run.out"; fail "every test here contains a failure, so the run must exit non-zero"; }
[ -f "$summary" ] || { cat "$workdir/run.out"; fail "no summary written at $summary"; }

python3 - "$summary" <<'PYEOF'
import json
import sys

summary = json.load(open(sys.argv[1]))
totals = summary["totals"]
by_id = {t["id"]: t["status"] for t in summary["tests"]}

# Tolerating a failure and letting teardown finish are both about which *steps*
# still run. Neither hides the failure itself, so all three tests fail.
for test_id in (
    "failure.steps-abort-at-the-first-failure",
    "failure.tolerated-failure-keeps-the-group-going",
    "failure.setup-failure-skips-the-body",
):
    assert by_id.get(test_id) == "failed", (test_id, by_id)

assert totals.get("failed") == 3, f"expected three failures, got {totals}"
assert totals.get("passed") == 0, f"nothing may pass in the negative suite, got {totals}"

# One step behind the aborted body, one behind the failed setup. The counter
# counts steps -- every other counter in this object counts tests.
assert totals.get("skippedSteps") == 2, f"expected two skipped steps, got {totals}"
PYEOF

# Allure is where the shape of the run is actually read. `skipped` is Allure's
# one word for "did not run", shared with ATDD `pending`; the step message tells
# them apart.
python3 - "$run_root/reports/allure" <<'PYEOF'
import json
import pathlib
import sys

by_test = {}
for path in pathlib.Path(sys.argv[1]).glob("*-result.json"):
    doc = json.loads(path.read_text())
    test_id = doc["historyId"].split("::", 1)[0]
    by_test[test_id] = [(s["name"], s["status"]) for s in doc.get("steps", [])]

def statuses(test_id):
    assert test_id in by_test, f"{test_id} produced no Allure result: {sorted(by_test)}"
    return [status for _, status in by_test[test_id]]

# The failure ends the group; the third step is named but never sent. Cleanup
# runs after it regardless, which is the last `passed`.
assert statuses("failure.steps-abort-at-the-first-failure") == [
    "passed",
    "failed",
    "skipped",
    "passed",
], by_test["failure.steps-abort-at-the-first-failure"]

# The tolerated failure is still a failure -- what it buys is the step after it.
assert statuses("failure.tolerated-failure-keeps-the-group-going") == [
    "failed",
    "passed",
    "passed",
], by_test["failure.tolerated-failure-keeps-the-group-going"]

# The precondition did not hold, so the body is not evidence about anything.
assert statuses("failure.setup-failure-skips-the-body") == [
    "failed",
    "skipped",
    "passed",
], by_test["failure.setup-failure-skips-the-body"]

# The whole point: what was skipped never reached the network.
for test_id, step_name in (
    ("failure.steps-abort-at-the-first-failure", "GET /posts/3 — must never be sent"),
    ("failure.setup-failure-skips-the-body", "GET /posts/1 — the actual check, never reached"),
):
    skipped = dict(by_test[test_id])
    assert skipped.get(step_name) == "skipped", (test_id, by_test[test_id])
PYEOF

echo "OK: a failure ends its group, continueOnError overrides it, and cleanup always runs"
