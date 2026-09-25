#!/usr/bin/env bash
# Run the Codex CLI and return only what Claude needs to read.
# Full logs are thousands of lines; they stay on disk.
#
#   run-codex.sh review --base main          # or --uncommitted, or --commit <sha>
#   run-codex.sh exec BRIEF.md [codex exec flags, e.g. -C <dir>]
#
# Output dir: $CODEX_OUT (default: ${TMPDIR:-/tmp}/codex-runs)
# Exit codes: 0 success, 1 other failure, 2 unknown mode, 3 exhausted quota.
set -euo pipefail
umask 077   # logs can contain source and secrets: owner-only
mode="${1:?usage: run-codex.sh review|exec ...}"; shift
out="${CODEX_OUT:-${TMPDIR:-/tmp}/codex-runs}"; mkdir -p "$out"
stamp="$(date +%Y%m%d-%H%M%S)-$$"   # PID suffix: parallel runs never share a file

report_failure() {
  echo "codex $mode failed (log: $log):"; tail -8 "$log"
  # Only classify failed invocations; successful reviews may discuss quota code.
  # A generic rate limit can be transient and must retain the normal retry path.
  if grep -Eiq 'usage[_ -]+limit|quota[[:space:]_-]+(exhausted|exceeded)|insufficient_quota|exceeded.*quota' "$log"; then
    echo "Codex quota exhausted; apply the documented review fallback."
    exit 3
  fi
  exit 1
}

case "$mode" in
  review)
    log="$out/review-$stamp.log"; findings="$out/review-$stamp.findings.md"
    if ! codex review "$@" >"$log" 2>&1; then
      report_failure
    fi
    # Findings are printed after the last "Full review comments:" marker (earlier copies repeat).
    # Match the marker only as a whole line: the log also contains file contents Codex read.
    if grep -qx "Full review comments:" "$log"; then
      awk '/^Full review comments:$/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$log" >"$findings"
    else
      # Clean review: keep Codex's final message (after its last "codex" line), deduplicated.
      awk '/^codex$/{buf=""; next} {buf=buf $0 "\n"} END{printf "%s", buf}' "$log" | awk '!seen[$0]++' >"$findings"
    fi
    echo "log: $log"; echo "findings: $findings"; echo; cat "$findings"
    ;;
  exec)
    brief="${1:?usage: run-codex.sh exec BRIEF.md [flags]}"; shift
    log="$out/exec-$stamp.log"; last="$out/exec-$stamp.last.md"
    if ! codex exec -s workspace-write -o "$last" "$@" - <"$brief" >"$log" 2>&1; then
      report_failure
    fi
    echo "log: $log"; echo; cat "$last"
    ;;
  *) echo "unknown mode: $mode" >&2; exit 2 ;;
esac
