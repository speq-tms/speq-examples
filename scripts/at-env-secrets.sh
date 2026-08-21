#!/usr/bin/env bash
# Acceptance test for ${ENV_VAR} substitution (speq-tms/speq-docs#60).
#
# Three things have to hold, and only the first is visible from a normal run:
#
#   1. a variable exported in the OS environment reaches the request;
#   2. ':-default' keeps the project runnable when it is not exported;
#   3. a placeholder with no default and no variable is a load-time error that
#      names the variable and the file, rather than a silent empty string.
#
# The redaction promise is checked alongside (1): the token must be present in
# the request attachment as '***', not as itself.
set -euo pipefail

SPEQ="${SPEQ_BIN:-speq}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$REPO/test-repo-mode-jsonplaceholder"
TOKEN="sp3q-demo-token-do-not-print"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1. an exported variable resolves, and is redacted everywhere ------------
run_root="$workdir/with-token"
cp -R "$ROOT" "$run_root"
rm -rf "$run_root/reports"

SPEQ_DEMO_TOKEN="$TOKEN" "$SPEQ" run --speq-root "$run_root" --env secrets \
  --report all --output "$run_root/reports/results/summary.json" >"$workdir/run.out" 2>&1 \
  || { cat "$workdir/run.out"; fail "the run should pass with the variable exported"; }

grep -q '"failed": 0' "$workdir/run.out" || { cat "$workdir/run.out"; fail "expected a green run"; }

# Everything the run wrote down, plus everything it printed.
if grep -rqF "$TOKEN" "$run_root/reports" "$workdir/run.out"; then
  grep -rlF "$TOKEN" "$run_root/reports" "$workdir/run.out" >&2
  fail "the token sourced from \${SPEQ_DEMO_TOKEN} leaked into run output"
fi
grep -rq 'authorization' "$run_root/reports/allure" \
  || fail "the authorization header never reached an attachment, so nothing was proven"
grep -rq '\*\*\*' "$run_root/reports/allure" \
  || fail "the token should appear redacted as '***', not merely be absent"

# --- 2. the default form keeps the project runnable -------------------------
default_root="$workdir/no-token"
cp -R "$ROOT" "$default_root"
rm -rf "$default_root/reports"

env -u SPEQ_DEMO_TOKEN -u SPEQ_DEMO_BASE_URL \
  "$SPEQ" run --speq-root "$default_root" --env secrets >"$workdir/default.out" 2>&1 \
  || { cat "$workdir/default.out"; fail "the run should pass on the ':-default' fallback"; }
grep -q '"failed": 0' "$workdir/default.out" || { cat "$workdir/default.out"; fail "expected a green run"; }

# --- 3. a placeholder with no default and no variable is a load-time error ---
strict_root="$workdir/strict"
cp -R "$ROOT" "$strict_root"
rm -rf "$strict_root/reports"
# Same file, with the fallbacks removed -- what a CI environment looks like.
cat > "$strict_root/environments/secrets.yaml" <<'YAML'
name: secrets
baseUrl: "https://jsonplaceholder.typicode.com"
headers:
  authorization: "Bearer ${SPEQ_DEMO_TOKEN}"
YAML

set +e
env -u SPEQ_DEMO_TOKEN "$SPEQ" validate --speq-root "$strict_root" >"$workdir/strict.out" 2>&1
strict_code=$?
set -e

[ "$strict_code" -ne 0 ] || { cat "$workdir/strict.out"; fail "validate must fail on an unresolvable variable"; }
grep -q 'unresolved_env_var' "$workdir/strict.out" || { cat "$workdir/strict.out"; fail "expected an unresolved_env_var error"; }
grep -q 'SPEQ_DEMO_TOKEN' "$workdir/strict.out" || fail "the error must name the variable"
grep -q 'secrets.yaml' "$workdir/strict.out" || fail "the error must name the file that referenced it"
[ ! -d "$strict_root/reports" ] || fail "validate must not execute anything"

echo "OK: substitution, the ':-default' fallback, the missing-variable error, and redaction all hold"
