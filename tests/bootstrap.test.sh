#!/usr/bin/env bash
# Smoke test: bootstrap installs every file, fills every placeholder, never overwrites.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
git init -q "$t"
echo "existing" >"$t/CLAUDE.md"
fail() { echo "FAIL: $*" >&2; exit 1; }

PROJECT_NAME=Demo PROJECT_PITCH="A demo tool." MAIN_BRANCH=main TEST_CMD="npm test" \
CHECK_CMD="npm run typecheck" CODEX_TEST_CMD="npx.cmd vitest run" CODEX_CHECK_CMD="npx.cmd tsc --noEmit" \
REVIEW_PRIORITIES="correctness." REVIEW_BUDGET="risk-based." M1_TITLE="First slice" "$kit/scripts/bootstrap.sh" "$t" >"$t/.out"

for f in AGENTS.md docs/DEVELOPMENT-PROCESS.md docs/ROADMAP.md docs/ARCHITECTURE.md \
         .github/ISSUE_TEMPLATE/backlog-finding.md .github/ISSUE_TEMPLATE/milestone-overview.md \
         .claude/skills/pairing-with-codex-cli/SKILL.md .claude/skills/pairing-with-codex-cli/run-codex.sh; do
  [ -f "$t/$f" ] || fail "missing $f"
done
[ "$(cat "$t/CLAUDE.md")" = existing ] || fail "CLAUDE.md was overwritten"
grep -q "= CLAUDE.md" "$t/.out" || fail "skipped file not reported"
if grep -rn "{{" "$t" --exclude-dir=.git --exclude=.out; then fail "unfilled placeholders"; fi
grep -q "M1 — First slice" "$t/docs/ROADMAP.md" || fail "milestone title not filled"
grep -q "risk-based." "$t/docs/ARCHITECTURE.md" || fail "REVIEW_BUDGET not filled into ARCHITECTURE.md"
grep -qx ".superpowers/" "$t/.gitignore" || fail ".superpowers/ not ignored"
bash -n "$t/.claude/skills/pairing-with-codex-cli/run-codex.sh" || fail "run-codex.sh syntax"

# Second run is a no-op that reports everything as skipped.
PROJECT_NAME=Demo PROJECT_PITCH=x MAIN_BRANCH=main TEST_CMD=x CHECK_CMD=x CODEX_TEST_CMD=x CODEX_CHECK_CMD=x \
REVIEW_PRIORITIES=x REVIEW_BUDGET=x M1_TITLE=x "$kit/scripts/bootstrap.sh" "$t" >"$t/.out2"
grep -q "^  + " "$t/.out2" && fail "second run wrote files"
[ "$(grep -c '^.superpowers/$' "$t/.gitignore")" = 1 ] || fail ".gitignore entry duplicated"
echo "bootstrap: all checks passed"
