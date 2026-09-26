#!/usr/bin/env bash
# Smoke test: bootstrap installs every file, fills every placeholder, never overwrites.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
# "python" first: on Windows, "python3" can be the Microsoft Store stub (matches scripts/bootstrap.sh).
py=""; for c in python python3; do if "$c" -c 1 >/dev/null 2>&1; then py="$c"; break; fi; done
[ -n "$py" ] || { echo "FAIL: no working python found" >&2; exit 1; }
t="$(mktemp -d)"; t2="$(mktemp -d)"; t3="$(mktemp -d)"; trap 'rm -rf "$t" "$t2" "$t3"' EXIT
git init -q "$t"
echo "existing" >"$t/CLAUDE.md"
mkdir -p "$t/.claude"
echo '{"custom": true}' >"$t/.claude/agents.json"
fail() { echo "FAIL: $*" >&2; exit 1; }

PROJECT_NAME=Demo PROJECT_PITCH="A demo tool." MAIN_BRANCH=main TEST_CMD="npm test" \
CHECK_CMD="npm run typecheck" CODEX_TEST_CMD="npx.cmd vitest run" CODEX_CHECK_CMD="npx.cmd tsc --noEmit" \
REVIEW_PRIORITIES="correctness." REVIEW_BUDGET="risk-based." M1_TITLE="First slice" \
LOCAL_LLM_BASE_URL="http://localhost:11434/v1" LOCAL_LLM_MODEL="llama3.1" \
"$kit/scripts/bootstrap.sh" "$t" >"$t/.out"

for f in AGENTS.md docs/DEVELOPMENT-PROCESS.md docs/ROADMAP.md docs/ARCHITECTURE.md \
         .github/ISSUE_TEMPLATE/backlog-finding.md .github/ISSUE_TEMPLATE/milestone-overview.md \
         .claude/skills/pairing-with-codex-cli/SKILL.md .claude/skills/pairing-with-codex-cli/run-codex.sh; do
  [ -f "$t/$f" ] || fail "missing $f"
done
[ "$(cat "$t/CLAUDE.md")" = existing ] || fail "CLAUDE.md was overwritten"
[ "$(cat "$t/.claude/agents.json")" = '{"custom": true}' ] || fail "existing .claude/agents.json was overwritten"
grep -q "= CLAUDE.md" "$t/.out" || fail "skipped file not reported"
grep -q "= .claude/agents.json" "$t/.out" || fail "skipped agents.json not reported"
if grep -rn "{{" "$t" --exclude-dir=.git --exclude=.out; then fail "unfilled placeholders"; fi
grep -q "M1 — First slice" "$t/docs/ROADMAP.md" || fail "milestone title not filled"
grep -q "risk-based." "$t/docs/ARCHITECTURE.md" || fail "REVIEW_BUDGET not filled into ARCHITECTURE.md"
grep -qx ".superpowers/" "$t/.gitignore" || fail ".superpowers/ not ignored"
bash -n "$t/.claude/skills/pairing-with-codex-cli/run-codex.sh" || fail "run-codex.sh syntax"

# Second run is a no-op that reports everything as skipped.
PROJECT_NAME=Demo PROJECT_PITCH=x MAIN_BRANCH=main TEST_CMD=x CHECK_CMD=x CODEX_TEST_CMD=x CODEX_CHECK_CMD=x \
REVIEW_PRIORITIES=x REVIEW_BUDGET=x M1_TITLE=x LOCAL_LLM_BASE_URL=x LOCAL_LLM_MODEL=x \
"$kit/scripts/bootstrap.sh" "$t" >"$t/.out2"
grep -q "^  + " "$t/.out2" && fail "second run wrote files"
[ "$(grep -c '^.superpowers/$' "$t/.gitignore")" = 1 ] || fail ".gitignore entry duplicated"

# A blank Local LLM answer disables the provider instead of leaving a half-filled config.
git init -q "$t2"
printf '\n\n' | PROJECT_NAME=Demo2 PROJECT_PITCH="A demo tool." MAIN_BRANCH=main TEST_CMD="npm test" \
CHECK_CMD="npm run typecheck" CODEX_TEST_CMD="npx.cmd vitest run" CODEX_CHECK_CMD="npx.cmd tsc --noEmit" \
REVIEW_PRIORITIES="correctness." REVIEW_BUDGET="risk-based." M1_TITLE="Second slice" \
"$kit/scripts/bootstrap.sh" "$t2" >"$t2/.out" || fail "bootstrap with blank local-LLM answers failed"
[ -f "$t2/.claude/agents.json" ] || fail "missing .claude/agents.json (blank-answer run)"
"$py" -m json.tool "$t2/.claude/agents.json" >/dev/null || fail "agents.json is not valid JSON (blank-answer run)"
grep -q '"local":.*"base_url": ""' "$t2/.claude/agents.json" || fail "blank LOCAL_LLM_BASE_URL should stay empty"
grep -q '"local":.*"enabled": false' "$t2/.claude/agents.json" || fail "blank LOCAL_LLM_BASE_URL should disable the local provider"

# A base URL with no model is rejected rather than silently half-configured.
git init -q "$t3"
if printf '\n' | PROJECT_NAME=Demo3 PROJECT_PITCH=x MAIN_BRANCH=main TEST_CMD=x CHECK_CMD=x CODEX_TEST_CMD=x CODEX_CHECK_CMD=x \
   REVIEW_PRIORITIES=x REVIEW_BUDGET=x M1_TITLE=x LOCAL_LLM_BASE_URL="http://localhost:11434/v1" \
   "$kit/scripts/bootstrap.sh" "$t3" >"$t3/.out3" 2>&1; then
  fail "bootstrap should reject a base URL with no model"
fi

echo "bootstrap: all checks passed"
