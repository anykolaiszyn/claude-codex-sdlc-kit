#!/usr/bin/env bash
# Exercise run-local-llm.sh's exit-code contract without a real LLM endpoint.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
script="$kit/skills/pairing-with-local-llms/run-local-llm.sh"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/repo"

cat >"$t/bin/curl" <<'SH'
#!/usr/bin/env bash
# Mimics: curl -sS --max-time N -o LOG -w '%{http_code}' -H ... -d PAYLOAD URL
outfile=""; prev=""; last=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then outfile="$a"; fi
  prev="$a"; last="$a"
done
printf '%s\n' "$last" >"${MOCK_CURL_URL_FILE:-/dev/null}"
if [ "${MOCK_CURL_STATUS:-0}" != 0 ]; then exit "$MOCK_CURL_STATUS"; fi
printf '%s' "${MOCK_CURL_BODY:-}" >"$outfile"
printf '%s' "${MOCK_CURL_HTTP:-200}"
SH
chmod +x "$t/bin/curl"
export PATH="$t/bin:$PATH"

git init -q "$t/repo"
git -C "$t/repo" config user.email test@example.com
git -C "$t/repo" config user.name Test
echo one >"$t/repo/f.txt"; git -C "$t/repo" add f.txt; git -C "$t/repo" commit -qm one
echo two >"$t/repo/f.txt"

run() { # run STATUS HTTP BODY -- extra-args...
  local mock_status="$1" mock_http="$2" mock_body="$3"; shift 3
  local status=0
  ( cd "$t/repo" && MOCK_CURL_STATUS="$mock_status" MOCK_CURL_HTTP="$mock_http" MOCK_CURL_BODY="$mock_body" \
      bash "$script" review --uncommitted --url http://localhost:11434/v1 --model test-model "$@" ) \
    >"$t/output" 2>&1 || status=$?
  return "$status"
}
check() {
  local expected="$1"; shift
  local status=0; run "$@" || status=$?
  [ "$status" = "$expected" ] || { echo "FAIL: expected $expected, got $status"; cat "$t/output"; exit 1; }
}

check 0 0 200 '{"choices":[{"message":{"content":"No findings."}}]}'
grep -q "No findings." "$t/output" || { echo "FAIL: findings not printed"; cat "$t/output"; exit 1; }

check 1 0 500 'server error'
check 3 7 200 ''
check 1 0 200 'not json'

# A trailing slash on --url must not produce a malformed double-slash request.
export MOCK_CURL_URL_FILE="$t/curl-url"
( cd "$t/repo" && MOCK_CURL_STATUS=0 MOCK_CURL_HTTP=200 MOCK_CURL_BODY='{"choices":[{"message":{"content":"ok"}}]}' \
    bash "$script" review --uncommitted --url http://localhost:11434/v1/ --model test-model ) >"$t/output" 2>&1 \
  || { echo "FAIL: trailing-slash URL should still succeed"; cat "$t/output"; exit 1; }
grep -qx "http://localhost:11434/v1/chat/completions" "$t/curl-url" \
  || { echo "FAIL: trailing slash produced a malformed URL: $(cat "$t/curl-url")"; exit 1; }
unset MOCK_CURL_URL_FILE

# Outside a git work tree, fail clearly instead of a raw git/curl error.
( cd "$t" && bash "$script" review --uncommitted --url http://localhost:11434/v1 --model test-model ) \
  >"$t/output" 2>&1 && { echo "FAIL: expected non-zero outside a git repo"; cat "$t/output"; exit 1; }
grep -qi "git" "$t/output" || { echo "FAIL: error message should mention git"; cat "$t/output"; exit 1; }

echo "run-local-llm: all checks passed"
