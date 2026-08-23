#!/usr/bin/env bash
# Acceptance test for the auth block (speq-tms/speq-docs#61).
#
# Four things have to hold, and a green run shows none of them:
#
#   1. a bearer block puts the credential on the wire and '***' in the report;
#   2. 'auth: none' sends nothing at all, which only the receiving end can see;
#   3. an OAuth2 run buys one token and presents it to every step that is due
#      one -- not one token per request;
#   4. neither the client secret nor the issued token survives into the report.
#
# JSONPlaceholder proves (1) against a real API. (2), (3) and (4) need a server
# that will say what it was sent, so the OAuth2 half runs against the stub
# identity provider started below.
set -euo pipefail

SPEQ="${SPEQ_BIN:-speq}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$REPO/test-repo-mode-jsonplaceholder"
BEARER="sp3q-demo-bearer-do-not-print"
CLIENT_SECRET="sp3q-stub-client-secret-do-not-print"

workdir="$(mktemp -d)"
stub_pid=""
cleanup() {
  if [ -n "$stub_pid" ]; then
    # Reaped here rather than left to the shell, which would otherwise print
    # its own "Terminated" line after this script's verdict.
    kill "$stub_pid" 2>/dev/null || true
    wait "$stub_pid" 2>/dev/null || true
  fi
  rm -rf "$workdir"
}
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1. bearer credentials against the real API -----------------------------
bearer_root="$workdir/bearer"
cp -R "$ROOT" "$bearer_root"
rm -rf "$bearer_root/reports"

SPEQ_DEMO_API_TOKEN="$BEARER" "$SPEQ" run --speq-root "$bearer_root" --env ci \
  --suite suites/auth --report all --output "$bearer_root/reports/results/summary.json" \
  >"$workdir/bearer.out" 2>&1 \
  || { cat "$workdir/bearer.out"; fail "the bearer suite should pass"; }

grep -q '"failed": 0' "$workdir/bearer.out" || { cat "$workdir/bearer.out"; fail "expected a green run"; }

if grep -rqF "$BEARER" "$bearer_root/reports" "$workdir/bearer.out"; then
  grep -rlF "$BEARER" "$bearer_root/reports" "$workdir/bearer.out" >&2
  fail "the bearer token reached the report"
fi
grep -rqi 'authorization' "$bearer_root/reports/allure" \
  || fail "no Authorization header ever reached an attachment, so nothing was proven"
grep -rq '\*\*\*' "$bearer_root/reports/allure" \
  || fail "the credential should appear redacted as '***', not merely be absent"

# --- the stub identity provider ---------------------------------------------
# Issues tokens, guards /orders with them, and writes down every request it was
# sent so the assertions below can read what actually went out.
cat > "$workdir/stub.py" <<'PY'
import http.server, json, os, socketserver, sys, threading

log_path, port_path = sys.argv[1], sys.argv[2]
secret = os.environ["SPEQ_OAUTH_CLIENT_SECRET"]
issued = 0
lock = threading.Lock()


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):  # keep the script's output readable
        pass

    def record(self):
        with lock, open(log_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({
                "method": self.command,
                "path": self.path,
                "authorization": self.headers.get("authorization"),
            }) + "\n")

    def answer(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        global issued
        self.record()
        if self.path != "/token":
            return self.answer(404, {"error": "not found"})
        length = int(self.headers.get("content-length") or 0)
        form = self.rfile.read(length).decode()
        fields = dict(p.split("=", 1) for p in form.split("&") if "=" in p)
        if fields.get("grant_type") != "client_credentials":
            return self.answer(400, {"error": "unsupported_grant_type"})
        if fields.get("client_secret") != secret:
            return self.answer(401, {"error": "invalid_client"})
        with lock:
            issued += 1
            token = f"stub-access-token-{issued}"
        self.answer(200, {"access_token": token, "token_type": "Bearer", "expires_in": 3600})

    def do_GET(self):
        self.record()
        if self.path.startswith("/public"):
            return self.answer(200, {"ok": True})
        auth = self.headers.get("authorization") or ""
        if not auth.startswith("Bearer stub-access-token-"):
            return self.answer(401, {"error": "unauthorized"})
        self.answer(200, [{"id": 1}])


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


with Server(("127.0.0.1", 0), Handler) as httpd:
    with open(port_path, "w", encoding="utf-8") as fh:
        fh.write(str(httpd.server_address[1]))
    httpd.serve_forever()
PY

log="$workdir/stub.log"
: > "$log"
SPEQ_OAUTH_CLIENT_SECRET="$CLIENT_SECRET" \
  python3 "$workdir/stub.py" "$log" "$workdir/port" &
stub_pid=$!

for _ in $(seq 1 50); do
  [ -s "$workdir/port" ] && break
  sleep 0.1
done
[ -s "$workdir/port" ] || fail "the stub identity provider never came up"
stub_url="http://127.0.0.1:$(cat "$workdir/port")"

# --- 2, 3, 4. the OAuth2 client-credentials flow -----------------------------
oauth_root="$workdir/oauth"
cp -R "$ROOT" "$oauth_root"
rm -rf "$oauth_root/reports"

SPEQ_OAUTH_STUB_URL="$stub_url" SPEQ_OAUTH_CLIENT_SECRET="$CLIENT_SECRET" \
  "$SPEQ" run --speq-root "$oauth_root" --env stub-oauth --suite stub-suites \
  --report all --output "$oauth_root/reports/results/summary.json" \
  >"$workdir/oauth.out" 2>&1 \
  || { cat "$workdir/oauth.out"; cat "$log"; fail "the oauth2 suite should pass"; }

grep -q '"failed": 0' "$workdir/oauth.out" || { cat "$workdir/oauth.out"; fail "expected a green run"; }

python3 - "$log" "$oauth_root" "$CLIENT_SECRET" <<'PY'
import json, pathlib, sys

log, root, secret = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
seen = [json.loads(line) for line in log.read_text().splitlines() if line.strip()]


def fail(message):
    print(f"FAIL: {message}", file=sys.stderr)
    print(json.dumps(seen, indent=2), file=sys.stderr)
    raise SystemExit(1)


tokens = [r for r in seen if r["path"] == "/token"]
if len(tokens) != 1:
    fail(f"the run asked for {len(tokens)} tokens; two steps share one")

orders = [r for r in seen if r["path"] == "/orders"]
if len(orders) != 2:
    fail(f"expected both guarded steps to be sent, saw {len(orders)}")
if not all((r["authorization"] or "").startswith("Bearer stub-access-token-") for r in orders):
    fail("a guarded step went out without the token it was due")
if len({r["authorization"] for r in orders}) != 1:
    fail("the second step was given a different token than the first")

public = [r for r in seen if r["path"] == "/public"]
if len(public) != 1:
    fail("the public probe did not run")
if public[0]["authorization"] is not None:
    fail("'auth: none' still sent an Authorization header")

# Nothing the flow touched may be readable in what the run wrote down.
written = (root / "reports/results/summary.json").read_text()
for path in sorted((root / "reports/allure").iterdir()):
    written += path.read_text()
for leaked in [secret, "stub-access-token-1"]:
    if leaked in written:
        fail(f"'{leaked}' survived into the report")
if "***" not in written:
    fail("the Authorization header should be reported redacted, not dropped")
PY

echo "OK: credentials are declared, presented, refused on request, bought once, and never reported"
