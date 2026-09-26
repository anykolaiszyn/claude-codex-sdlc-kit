#!/usr/bin/env bash
# Run a review against a local OpenAI-compatible LLM endpoint and return only
# what Claude needs to read. Full request/response logs stay on disk.
#
#   run-local-llm.sh review --base <branch> --url <base-url> --model <name> [--timeout <secs>]
#   run-local-llm.sh review --uncommitted --url <base-url> --model <name>
#   run-local-llm.sh review --commit <sha> --url <base-url> --model <name>
#
# Exit codes: 0 success (findings printed, possibly none), 1 reachable but
# failed/malformed response, 3 endpoint unreachable (the caller should fall
# through to the role's next configured provider).
# Output dir: $LOCAL_LLM_OUT (default: ${TMPDIR:-/tmp}/local-llm-runs)
set -euo pipefail
umask 077   # logs can contain source: owner-only

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not inside a git work tree" >&2; exit 1; }

# "python" first: on Windows, "python3" can be the Microsoft Store stub.
py=""; for c in python python3; do if "$c" -c 1 >/dev/null 2>&1; then py="$c"; break; fi; done
[ -n "$py" ] || { echo "Python 3 is required" >&2; exit 1; }

mode="${1:?usage: run-local-llm.sh review --base <b>|--uncommitted|--commit <sha> --url <url> --model <name>}"; shift
[ "$mode" = review ] || { echo "unknown mode: $mode" >&2; exit 2; }

diff_mode=""; diff_arg=""; url=""; model=""; timeout=60
while [ $# -gt 0 ]; do
  case "$1" in
    --base) diff_mode=base; diff_arg="${2:?--base needs a branch}"; shift 2 ;;
    --uncommitted) diff_mode=uncommitted; shift ;;
    --commit) diff_mode=commit; diff_arg="${2:?--commit needs a sha}"; shift 2 ;;
    --url) url="${2:?--url needs a value}"; shift 2 ;;
    --model) model="${2:?--model needs a value}"; shift 2 ;;
    --timeout) timeout="${2:?--timeout needs a value}"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[ -n "$diff_mode" ] || { echo "one of --base/--uncommitted/--commit is required" >&2; exit 2; }
[ -n "$url" ] && [ -n "$model" ] || { echo "--url and --model are required" >&2; exit 2; }
url="${url%/}"   # a trailing slash would turn "$url/chat/completions" into a double slash

case "$diff_mode" in
  base) diff="$(git diff "$diff_arg"...HEAD)" ;;
  uncommitted) diff="$(git diff HEAD)" ;;
  commit) diff="$(git show "$diff_arg")" ;;
esac
[ -n "$diff" ] || { echo "no diff to review"; exit 0; }

out="${LOCAL_LLM_OUT:-${TMPDIR:-/tmp}/local-llm-runs}"; mkdir -p "$out"
stamp="$(date +%Y%m%d-%H%M%S)-$$"   # PID suffix: parallel runs never share a file
log="$out/review-$stamp.log"; findings="$out/review-$stamp.findings.md"

prompt=$'You are reviewing a code change. For each real issue, state whether it is BLOCKING (wrong output/behaviour, a crash, or a spec violation) or an EDGE CASE (valid but out of scope), with a concrete failing input. If there are no issues, say "No findings." Do not repeat the diff back.\n\nDiff:\n'"$diff"

payload="$(model="$model" prompt="$prompt" "$py" - <<'PY'
import json, os
print(json.dumps({"model": os.environ["model"], "messages": [{"role": "user", "content": os.environ["prompt"]}]}))
PY
)"

status=0
http_code="$(curl -sS --max-time "$timeout" -o "$log" -w '%{http_code}' \
  -H 'Content-Type: application/json' -d "$payload" "$url/chat/completions")" || status=$?

if [ "$status" != 0 ]; then
  echo "local LLM unreachable at $url (log: $log)"; exit 3
fi
if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
  echo "local LLM returned HTTP $http_code (log: $log):"; tail -c 400 "$log"; exit 1
fi

if ! "$py" - "$log" "$findings" <<'PY'
import json, sys
log_path, out_path = sys.argv[1], sys.argv[2]
data = json.load(open(log_path, encoding="utf-8"))
content = data["choices"][0]["message"]["content"]
open(out_path, "w", encoding="utf-8").write(content)
PY
then
  echo "local LLM response was not the expected shape (log: $log)"; exit 1
fi

echo "log: $log"; echo "findings: $findings"; echo; cat "$findings"
