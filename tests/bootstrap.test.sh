#!/usr/bin/env bash
# Smoke test: bootstrap installs every file, fills every placeholder, never overwrites.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
# "python" first: on Windows, "python3" can be the Microsoft Store stub (matches scripts/bootstrap.sh).
py=""; for c in python python3; do if "$c" -c 1 >/dev/null 2>&1; then py="$c"; break; fi; done
[ -n "$py" ] || { echo "FAIL: no working python found" >&2; exit 1; }
t="$(mktemp -d)"; t2="$(mktemp -d)"; t3="$(mktemp -d)"; t4="$(mktemp -d)"; t5="$(mktemp -d)"
trap 'rm -rf "$t" "$t2" "$t3" "$t4" "$t5"' EXIT
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
         .claude/skills/pairing-with-codex-cli/SKILL.md .claude/skills/pairing-with-codex-cli/run-codex.sh \
         .claude/skills/pairing-with-local-llms/SKILL.md .claude/skills/pairing-with-local-llms/run-local-llm.sh; do
  [ -f "$t/$f" ] || fail "missing $f"
done
[ "$(cat "$t/CLAUDE.md")" = existing ] || fail "CLAUDE.md was overwritten"
[ "$(cat "$t/.claude/agents.json")" = '{"custom": true}' ] || fail "existing .claude/agents.json was overwritten"
grep -q "= CLAUDE.md" "$t/.out" || fail "skipped file not reported"
grep -q "= .claude/agents.json" "$t/.out" || fail "skipped agents.json not reported"
if grep -rn "{{" "$t" --exclude-dir=.git --exclude=.out; then fail "unfilled placeholders"; fi
grep -q "M1 — First slice" "$t/docs/ROADMAP.md" || fail "milestone title not filled"
grep -q "risk-based." "$t/docs/ARCHITECTURE.md" || fail "REVIEW_BUDGET not filled into ARCHITECTURE.md"
grep -q "Provider assignment" "$t/docs/DEVELOPMENT-PROCESS.md" || fail "Provider assignment section missing from DEVELOPMENT-PROCESS.md"
grep -q ".claude/agents.json" "$t/docs/DEVELOPMENT-PROCESS.md" || fail "DEVELOPMENT-PROCESS.md doesn't reference agents.json"
grep -q "Which provider actually performs the gate" "$t/docs/DEVELOPMENT-PROCESS.md" || fail "PR follow-up loop doesn't cross-reference the pr_gate role"
grep -q "per the \`pre_pr_review\` role" "$t/docs/DEVELOPMENT-PROCESS.md" || fail "Unattended mode doesn't cross-reference the pre_pr_review role"
grep -q ".claude/agents.json" "$kit/template/CLAUDE.md" || fail "template/CLAUDE.md doesn't reference agents.json"
grep -q ".claude/agents.json" "$t/AGENTS.md" || fail "installed AGENTS.md doesn't reference agents.json"
grep -qx ".superpowers/" "$t/.gitignore" || fail ".superpowers/ not ignored"
bash -n "$t/.claude/skills/pairing-with-codex-cli/run-codex.sh" || fail "run-codex.sh syntax"
bash -n "$t/.claude/skills/pairing-with-local-llms/run-local-llm.sh" || fail "run-local-llm.sh syntax"

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

# Non-interactive automation (no terminal, LOCAL_LLM_* never set) must still succeed, not crash silently.
git init -q "$t4"
PROJECT_NAME=Demo4 PROJECT_PITCH=x MAIN_BRANCH=main TEST_CMD=x CHECK_CMD=x CODEX_TEST_CMD=x CODEX_CHECK_CMD=x \
REVIEW_PRIORITIES=x REVIEW_BUDGET=x M1_TITLE=x \
"$kit/scripts/bootstrap.sh" "$t4" </dev/null >"$t4/.out4" 2>&1 \
  || fail "non-interactive bootstrap with no LOCAL_LLM_* answers crashed: $(cat "$t4/.out4")"
[ -f "$t4/.claude/agents.json" ] || fail "missing .claude/agents.json (non-interactive run)"
grep -q '"local":.*"enabled": false' "$t4/.claude/agents.json" || fail "non-interactive run should default local to disabled"

# A pre-existing (skipped) skill script must not have its permissions
# touched — the bootstrap's "never overwrites" contract covers mode too,
# not just content.
git init -q "$t5"
mkdir -p "$t5/.claude/skills/pairing-with-codex-cli" "$t5/.claude/skills/pairing-with-local-llms"
echo "existing codex script" >"$t5/.claude/skills/pairing-with-codex-cli/run-codex.sh"
echo "existing local-llm script" >"$t5/.claude/skills/pairing-with-local-llms/run-local-llm.sh"
real_chmod="$(command -v chmod)"
mkdir -p "$t5/bin"
cat >"$t5/bin/chmod" <<CHMODEOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$t5/chmod-log"
exec "$real_chmod" "\$@"
CHMODEOF
chmod +x "$t5/bin/chmod"
PATH="$t5/bin:$PATH" PROJECT_NAME=Demo5 PROJECT_PITCH=x MAIN_BRANCH=main TEST_CMD=x CHECK_CMD=x CODEX_TEST_CMD=x CODEX_CHECK_CMD=x \
REVIEW_PRIORITIES=x REVIEW_BUDGET=x M1_TITLE=x LOCAL_LLM_BASE_URL=x LOCAL_LLM_MODEL=x \
"$kit/scripts/bootstrap.sh" "$t5" >"$t5/.out5"
touch "$t5/chmod-log"
grep -q "run-codex.sh" "$t5/chmod-log" && fail "chmod ran on a skipped (pre-existing) run-codex.sh"
grep -q "run-local-llm.sh" "$t5/chmod-log" && fail "chmod ran on a skipped (pre-existing) run-local-llm.sh"

echo "bootstrap: all checks passed"
