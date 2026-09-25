#!/usr/bin/env bash
# Exercise wrapper exit codes without spending Codex quota.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin"
cat >"$t/bin/codex" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$MOCK_MESSAGE"
if [ "$1" = exec ] && [ "$MOCK_STATUS" = 0 ]; then
  shift
  while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then shift; printf 'done\n' >"$1"; break; fi
    shift
  done
fi
exit "$MOCK_STATUS"
SH
chmod +x "$t/bin/codex"
export PATH="$t/bin:$PATH" CODEX_OUT="$t/logs"
printf 'test brief\n' >"$t/brief.md"
check() {
  local mode="$1" expected="$2" status=0
  export MOCK_STATUS="$3" MOCK_MESSAGE="$4"
  local args=(review --base main)
  if [ "$mode" = exec ]; then args=(exec "$t/brief.md"); fi
  bash "$kit/skills/pairing-with-codex-cli/run-codex.sh" "${args[@]}" >"$t/output" 2>&1 || status=$?
  [ "$status" = "$expected" ] || { echo "FAIL: $mode expected $expected, got $status ($MOCK_MESSAGE)"; exit 1; }
}
for mode in review exec; do
  check "$mode" 3 1 "ERROR: You've hit your usage limit."
  check "$mode" 3 1 'ERROR: quota exhausted'
  check "$mode" 3 1 'ERROR: insufficient_quota'
  check "$mode" 1 1 'ERROR: connection reset'
  check "$mode" 1 1 'ERROR: rate limit reached; retry shortly'
  check "$mode" 0 0 'Review discusses quota exhausted handling; no findings.'
done
echo 'run-codex: all checks passed'
