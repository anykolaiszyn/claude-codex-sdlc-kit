# Agent Provider Roles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let every SDLC role (implementation, per-task review, pre-PR bug hunt, final review, PR gate) be assigned to a provider — Codex, a specific Claude model, or a local OpenAI-compatible LLM — via a new per-repo config file, with any provider disableable in one edit, fully backward compatible with repos that don't opt in.

**Architecture:** A new declarative file, `.claude/agents.json`, defines named `providers` (each with a `kind` and an `enabled` flag) and maps the five fixed `roles` to an ordered fallback list of provider names. No dispatcher script resolves it — Claude reads the file directly each session and picks the mechanism (an `Agent` call, `run-codex.sh`, or the new `run-local-llm.sh`) that matches the resolved provider's `kind`. The plugin package is renamed (`agent-sdlc` / `agent-sdlc-kit`); the GitHub repo path is untouched.

**Tech Stack:** Bash (`set -euo pipefail`), Python 3 (already required by `bootstrap.sh`'s `fill()` and used here for JSON encode/decode), `curl`, GitHub Actions CI, Claude Code plugin manifests (JSON).

**Spec:** [docs/superpowers/specs/2026-09-26-agent-provider-roles-design.md](../specs/2026-09-26-agent-provider-roles-design.md)

## Global Constraints

- Backward compatible: a repo with no `.claude/agents.json` behaves exactly as documented today — no functional change until it opts in.
- `bootstrap.sh` never overwrites an existing file; it reports skips instead (applies to `.claude/agents.json` like any other installed file).
- No dispatcher script. `.claude/agents.json` has exactly one reader in this design: Claude itself.
- Local (`openai-http`) providers are review-only in this pass — never assign one to the `implementation` role.
- The GitHub repo path `anykolaiszyn/claude-codex-sdlc-kit` does not change. Only `.claude-plugin/plugin.json`'s `name` (→ `agent-sdlc`) and `.claude-plugin/marketplace.json`'s `name`/`plugins[0].name` (→ `agent-sdlc-kit` / `agent-sdlc`) change.
- `run-local-llm.sh` exit codes: **0** success (findings printed, possibly "No findings."), **1** reachable but failed/malformed response, **3** endpoint unreachable (the signal that makes a role fall through to its next configured provider) — same shape as `run-codex.sh`'s existing exit-1/quota-style contract, so triage/failover logic reads either script's result the same way.
- Shell scripts stay portable (Git Bash, macOS, Linux): quote paths, avoid GNU-only flags.
- `template/docs/DEVELOPMENT-PROCESS.md`, `skills/pairing-with-codex-cli/SKILL.md`, and `commands/` must stay in step per `CONTRIBUTING.md` — this plan only touches the first; the other two are explicitly unmodified (see spec **Non-goals**).

## Review Focus

1. **A repo that already hand-edited `.claude/agents.json` re-runs bootstrap.** It must be skipped like any other existing file, never overwritten — pinned in Task 1.
2. **`LOCAL_LLM_BASE_URL` given without `LOCAL_LLM_MODEL` (or vice versa).** A half-specified local provider must not silently become `"enabled": true` with a blank field that fails on every real call — bootstrap should refuse to proceed — pinned in Task 1.
3. **A `base_url` with a trailing slash** (e.g. `http://localhost:11434/v1/`). `run-local-llm.sh` appends `/chat/completions` directly; an unstripped trailing slash produces a malformed double-slash URL — pinned in Task 2.
4. **A 200 response whose body isn't the expected JSON shape** (e.g. a proxy's HTML error page returned with a 200 status). Must exit 1 cleanly, never a raw Python traceback — pinned in Task 2.
5. **Running `run-local-llm.sh` outside a git work tree.** `git diff`/`git show` must fail with a clear message and exit 1, not a cryptic downstream error — pinned in Task 2.

---

### Task 1: `.claude/agents.json` template and bootstrap plumbing

**Files:**
- Create: `template/.claude/agents.json`
- Modify: `scripts/bootstrap.sh`
- Modify: `tests/bootstrap.test.sh`

**Interfaces:**
- Produces: the installed file `.claude/agents.json`, with top-level keys `providers` (map of provider name → `{kind, enabled, ...kind-specific fields}`) and `roles` (map of role name → `{providers: [name, ...]}`). Provider names used elsewhere in this plan: `codex-cli`, `codex-cloud-bot`, `claude-sonnet`, `claude-opus`, `claude-haiku`, `local`. Role names: `implementation`, `task_review`, `pre_pr_review`, `final_review`, `pr_gate`.
- Produces: `bootstrap.sh` env vars `LOCAL_LLM_BASE_URL`, `LOCAL_LLM_MODEL` (user-supplied, default empty), `LOCAL_LLM_ENABLED` (derived: `"true"` if `LOCAL_LLM_BASE_URL` is non-empty, else `"false"`).

- [ ] **Step 1: Write the failing bootstrap assertions**

Edit `tests/bootstrap.test.sh` to its new full contents:

```bash
#!/usr/bin/env bash
# Smoke test: bootstrap installs every file, fills every placeholder, never overwrites.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
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
python3 -m json.tool "$t2/.claude/agents.json" >/dev/null || fail "agents.json is not valid JSON (blank-answer run)"
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
```

This references `.claude/agents.json`, `LOCAL_LLM_BASE_URL`, `LOCAL_LLM_MODEL` before `bootstrap.sh` or the template file exist yet.

- [ ] **Step 2: Run it and confirm it fails**

Run: `bash tests/bootstrap.test.sh`
Expected: FAIL — the run either errors because `LOCAL_LLM_BASE_URL`/`LOCAL_LLM_MODEL` aren't recognized answers yet (`bootstrap.sh` will still complete, since unknown env vars are simply ignored by the current script), or the `[ -f "$t/.claude/agents.json" ]`-style assertions fail because the file was never created. Confirm the failure is one of these missing-file/content assertions, not a syntax error in the test script itself.

- [ ] **Step 3: Create the config template**

Create `template/.claude/agents.json`:

```json
{
  "providers": {
    "codex-cli":       { "kind": "codex-cli", "enabled": true },
    "codex-cloud-bot": { "kind": "codex-cloud-bot", "enabled": true },
    "claude-sonnet":   { "kind": "claude-subagent", "model": "sonnet", "enabled": true },
    "claude-opus":     { "kind": "claude-subagent", "model": "opus", "enabled": true },
    "claude-haiku":    { "kind": "claude-subagent", "model": "haiku", "enabled": true },
    "local":           { "kind": "openai-http", "base_url": "{{LOCAL_LLM_BASE_URL}}", "model": "{{LOCAL_LLM_MODEL}}", "enabled": {{LOCAL_LLM_ENABLED}} }
  },
  "roles": {
    "implementation": { "providers": ["codex-cli", "claude-sonnet"] },
    "task_review":    { "providers": ["claude-sonnet"] },
    "pre_pr_review":  { "providers": ["codex-cli", "local", "claude-sonnet"] },
    "final_review":   { "providers": ["claude-opus"] },
    "pr_gate":        { "providers": ["codex-cloud-bot"] }
  }
}
```

- [ ] **Step 4: Wire the new answers into `bootstrap.sh`**

In `scripts/bootstrap.sh`, update the header comment (currently listing the env vars) to add `LOCAL_LLM_BASE_URL  LOCAL_LLM_MODEL`, then insert this block right after the existing `[ -n "$M1_TITLE" ] || M1_TITLE="TODO"` line and before the `# "python" first: ...` comment:

```bash
ask LOCAL_LLM_BASE_URL "Local LLM endpoint (OpenAI-compatible base URL; blank to skip)" ""
ask LOCAL_LLM_MODEL    "Local LLM model name (only used if a base URL was given)"       ""
if [ -n "$LOCAL_LLM_BASE_URL" ] && [ -z "$LOCAL_LLM_MODEL" ]; then
  echo "LOCAL_LLM_MODEL is required when LOCAL_LLM_BASE_URL is set" >&2; exit 1
fi
if [ -z "$LOCAL_LLM_BASE_URL" ] && [ -n "$LOCAL_LLM_MODEL" ]; then
  echo "LOCAL_LLM_BASE_URL is required when LOCAL_LLM_MODEL is set" >&2; exit 1
fi
if [ -n "$LOCAL_LLM_BASE_URL" ]; then LOCAL_LLM_ENABLED=true; else LOCAL_LLM_ENABLED=false; fi
export LOCAL_LLM_ENABLED
```

No change is needed to `install_tree` — `template/.claude/agents.json` is copied automatically by the existing `install_tree "$kit/template" ""` call, since it walks the whole `template/` tree.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `bash tests/bootstrap.test.sh`
Expected: PASS — `bootstrap: all checks passed`.

Note while debugging: the test pre-creates `$t/.claude/agents.json` with `{"custom": true}` specifically to prove the skip-existing-file behavior; don't "fix" a failure there by changing that fixture — the fixture is intentional (mirrors the existing `CLAUDE.md` skip fixture just above it).

- [ ] **Step 6: Commit**

```bash
git add template/.claude/agents.json scripts/bootstrap.sh tests/bootstrap.test.sh
git commit -m "feat: add .claude/agents.json provider config and bootstrap plumbing"
```

---

### Task 2: Local LLM review adapter (`run-local-llm.sh` + `pairing-with-local-llms` skill)

**Files:**
- Create: `skills/pairing-with-local-llms/run-local-llm.sh`
- Create: `skills/pairing-with-local-llms/SKILL.md`
- Create: `tests/run-local-llm.test.sh`
- Modify: `scripts/bootstrap.sh`
- Modify: `tests/bootstrap.test.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nothing from Task 1's code (it reads `--url`/`--model` from CLI flags that Claude supplies after resolving a role — see spec's **Role resolution** — not from `.claude/agents.json` itself).
- Produces: `run-local-llm.sh review --base <branch>|--uncommitted|--commit <sha> --url <base-url> --model <name> [--timeout <secs>]`, exit 0/1/3 per **Global Constraints**, findings printed to stdout, full request/response logged under `$LOCAL_LLM_OUT` (default `${TMPDIR:-/tmp}/local-llm-runs`).

- [ ] **Step 1: Write the failing wrapper test**

Create `tests/run-local-llm.test.sh`:

```bash
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
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `bash tests/run-local-llm.test.sh`
Expected: FAIL — `skills/pairing-with-local-llms/run-local-llm.sh: No such file or directory` (or similar), since the script doesn't exist yet.

- [ ] **Step 3: Implement `run-local-llm.sh`**

Create `skills/pairing-with-local-llms/run-local-llm.sh`:

```bash
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

payload="$(model="$model" prompt="$prompt" python3 - <<'PY'
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

if ! python3 - "$log" "$findings" <<'PY'
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
```

- [ ] **Step 4: Write the skill doc**

Create `skills/pairing-with-local-llms/SKILL.md`:

```markdown
---
name: pairing-with-local-llms
description: Use when a role in .claude/agents.json resolves to a "local" (openai-http) provider — running a review against a local OpenAI-compatible LLM endpoint (Ollama, LM Studio, vLLM, llama.cpp server, etc.) and triaging its findings.
---

# Pairing with local LLMs

## Overview

Some SDLC roles can be assigned to a local model server instead of Codex or a Claude subagent — see `.claude/agents.json`. **Its output is a claim, not evidence**, exactly like Codex's: verify every finding before acting on it. Local models have no quota to exhaust, but they aren't guaranteed to be running or reachable either.

## Running it

Always use `run-local-llm.sh` (in this skill's directory). It builds the diff itself, posts it to the configured endpoint, saves the full request/response to disk, and prints only the findings. **Never read the raw log.**

```bash
S=.claude/skills/pairing-with-local-llms   # repo copy; if absent, use this skill's base directory
"$S/run-local-llm.sh" review --base <PR base branch> --url <provider base_url> --model <provider model>
"$S/run-local-llm.sh" review --uncommitted --url <provider base_url> --model <provider model>
```

Read `--url` and `--model` from the resolved provider's entry in `.claude/agents.json` (e.g. `providers.local.base_url` / `.model`) — don't hardcode them.

Gotchas:
- **Exit 3 means the endpoint is unreachable**, not "no findings" — fall through to the role's next configured provider (see `docs/DEVELOPMENT-PROCESS.md` → **Provider assignment**), same idea as a Codex quota failure. Exit **1** is a reachable-but-failed response (bad HTTP status, or a response that isn't the expected `choices[0].message.content` shape). Exit **0** means success, findings printed (possibly "No findings.").
- Local models typically have much smaller context windows than Codex or Claude. Keep the reviewed diff scoped — the "review only the changed surface" rule from `pairing-with-codex-cli` applies here even more strictly.
- No `exec`/delegation mode. Local providers are review-only for now — see the design spec's **Non-goals**.
- Availability isn't guaranteed the way a paid API's uptime is. Don't assume a role assigned to `local` will always succeed; the fallback chain in `.claude/agents.json` exists for exactly this.

## Triage every finding (required)

Same rule as Codex's, not a separate one: reproduce with a probe, record Valid/Invalid/Unclear, fix blocking findings test-first, open a backlog issue for valid-but-out-of-scope ones, reply with evidence for invalid ones. See `pairing-with-codex-cli` → **Triage every finding** for the full procedure — it applies unchanged regardless of which provider produced the finding.

## Common mistakes

| Mistake | Fix |
|---|---|
| Reading the raw log directly | Use `run-local-llm.sh`, which prints findings only |
| Treating exit 3 as "no findings" | It means unreachable — fall through the provider chain |
| Assigning `implementation` to a local provider | Not supported yet — local providers are review-only |
| Pasting the whole branch history into one review | Keep the diff scoped; local models have small context windows |
```

- [ ] **Step 5: Wire installation into `bootstrap.sh`**

In `scripts/bootstrap.sh`, right after the existing:

```bash
install_tree "$kit/skills/pairing-with-codex-cli" ".claude/skills/pairing-with-codex-cli/"
chmod +x "$target/.claude/skills/pairing-with-codex-cli/run-codex.sh" 2>/dev/null || true
```

add:

```bash
install_tree "$kit/skills/pairing-with-local-llms" ".claude/skills/pairing-with-local-llms/"
chmod +x "$target/.claude/skills/pairing-with-local-llms/run-local-llm.sh" 2>/dev/null || true
```

and update the final hint line from:

```bash
echo "Stage the script as executable: git add --chmod=+x .claude/skills/pairing-with-codex-cli/run-codex.sh"
```

to:

```bash
echo "Stage the scripts as executable: git add --chmod=+x .claude/skills/pairing-with-codex-cli/run-codex.sh .claude/skills/pairing-with-local-llms/run-local-llm.sh"
```

- [ ] **Step 6: Extend `tests/bootstrap.test.sh` for the new skill files**

In the `for f in ...` list (the one asserting installed files exist), add two entries after the existing `pairing-with-codex-cli` ones:

```bash
for f in AGENTS.md docs/DEVELOPMENT-PROCESS.md docs/ROADMAP.md docs/ARCHITECTURE.md \
         .github/ISSUE_TEMPLATE/backlog-finding.md .github/ISSUE_TEMPLATE/milestone-overview.md \
         .claude/skills/pairing-with-codex-cli/SKILL.md .claude/skills/pairing-with-codex-cli/run-codex.sh \
         .claude/skills/pairing-with-local-llms/SKILL.md .claude/skills/pairing-with-local-llms/run-local-llm.sh; do
  [ -f "$t/$f" ] || fail "missing $f"
done
```

and after the existing `bash -n ".../run-codex.sh"` line, add:

```bash
bash -n "$t/.claude/skills/pairing-with-local-llms/run-local-llm.sh" || fail "run-local-llm.sh syntax"
```

- [ ] **Step 7: Run both test suites and confirm they pass**

Run: `bash tests/run-local-llm.test.sh`
Expected: PASS — `run-local-llm: all checks passed`.

Run: `bash tests/bootstrap.test.sh`
Expected: PASS — `bootstrap: all checks passed`.

- [ ] **Step 8: Update CI**

In `.github/workflows/ci.yml`, change the ShellCheck step's `run:` line from:

```yaml
        run: shellcheck scripts/*.sh tests/*.sh skills/pairing-with-codex-cli/run-codex.sh
```

to:

```yaml
        run: shellcheck scripts/*.sh tests/*.sh skills/pairing-with-codex-cli/run-codex.sh skills/pairing-with-local-llms/run-local-llm.sh
```

and add a new step after "Bootstrap smoke test":

```yaml
      - name: Local LLM wrapper tests
        run: bash tests/run-local-llm.test.sh
```

Run: `shellcheck scripts/*.sh tests/*.sh skills/pairing-with-codex-cli/run-codex.sh skills/pairing-with-local-llms/run-local-llm.sh`
Expected: no warnings (fix any that appear before moving on).

- [ ] **Step 9: Commit**

```bash
git add skills/pairing-with-local-llms tests/run-local-llm.test.sh scripts/bootstrap.sh tests/bootstrap.test.sh .github/workflows/ci.yml
git commit -m "feat: add pairing-with-local-llms skill and run-local-llm.sh adapter"
```

---

### Task 3: Reference provider assignment in `template/docs/DEVELOPMENT-PROCESS.md`

**Files:**
- Modify: `template/docs/DEVELOPMENT-PROCESS.md`
- Modify: `tests/bootstrap.test.sh`

**Interfaces:**
- Consumes: role/provider names from Task 1 (`implementation`, `task_review`, `pre_pr_review`, `final_review`, `pr_gate`; `codex-cli`, `codex-cloud-bot`).

- [ ] **Step 1: Write the failing assertions**

Add to `tests/bootstrap.test.sh`, after the existing `grep -q "risk-based." ...ARCHITECTURE.md...` line:

```bash
grep -q "Provider assignment" "$t/docs/DEVELOPMENT-PROCESS.md" || fail "Provider assignment section missing from DEVELOPMENT-PROCESS.md"
grep -q ".claude/agents.json" "$t/docs/DEVELOPMENT-PROCESS.md" || fail "DEVELOPMENT-PROCESS.md doesn't reference agents.json"
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `bash tests/bootstrap.test.sh`
Expected: FAIL on one or both new `grep` assertions (the section and reference don't exist yet).

- [ ] **Step 3: Update the Roles table's "Who" column**

In `template/docs/DEVELOPMENT-PROCESS.md`, replace the Roles table:

```markdown
| Role | Who | Rules |
|---|---|---|
| Orchestrator: design, specs, plans, rulings, every commit and push | Claude (main session) | Holds the approval gates with the user; the only agent that touches git history or GitHub |
| Implementation where the plan contains the code | Codex `exec` (default) | Brief file in the skill's format; test-first; never touches git; Claude reviews the diff and reruns the tests |
| Same, fallback | Claude Haiku subagent | When Codex can't run the tests, or a brief fails two rounds |
| Implementation needing judgment or spanning files | Claude Sonnet subagent | Per `superpowers:subagent-driven-development` |
| Per-task review against the spec | Claude Sonnet | Needs the task brief, spec and global constraints |
| Bug hunt before a PR is opened or updated | Codex `review --base <base>` (local) | Every finding probed before acting |
| Final whole-branch review | Claude Opus | Once per branch |
| PR gate | Codex cloud ("@codex review") | PR follow-up loop |
```

with:

```markdown
| Role | Who | Rules |
|---|---|---|
| Orchestrator: design, specs, plans, rulings, every commit and push | Claude (main session) | Holds the approval gates with the user; the only agent that touches git history or GitHub |
| Implementation where the plan contains the code | `implementation` role in `.claude/agents.json` (default: Codex `exec`) | Brief file in the skill's format; test-first; never touches git; Claude reviews the diff and reruns the tests |
| Same, fallback | Claude Haiku subagent | When the resolved provider can't run the tests, or a brief fails two rounds |
| Implementation needing judgment or spanning files | Claude Sonnet subagent | Per `superpowers:subagent-driven-development` |
| Per-task review against the spec | `task_review` role (default: Claude Sonnet) | Needs the task brief, spec and global constraints |
| Bug hunt before a PR is opened or updated | `pre_pr_review` role (default: Codex `review --base <base>`, local) | Every finding probed before acting |
| Final whole-branch review | `final_review` role (default: Claude Opus) | Once per branch |
| PR gate | `pr_gate` role (default: Codex cloud, "@codex review") | PR follow-up loop |
```

- [ ] **Step 4: Add the "Provider assignment" section**

Insert a new section immediately after the Roles table's "Rules everywhere" bullet list and before `## Review budget`:

```markdown
## Provider assignment

Each role in the table above resolves to a provider through `.claude/agents.json`: an ordered list of provider names per role, and an `enabled` flag on each provider (see the file itself for the schema). Claude resolves a role by walking its list and taking the first entry with `enabled: true`; for a `local` (OpenAI-compatible HTTP) provider, an unreachable endpoint at call time counts the same as "not usable" and falls through to the next entry. If nothing in a role's chain is usable, apply the **Review budget** and **Failover and quota handling** rules below exactly as if the default provider had hit its limit.

A repo with no `.claude/agents.json` behaves exactly as this table's defaults describe — the file is additive, not required.

To pause a provider without editing every role that uses it (for example, to stop spending a ChatGPT quota you're using elsewhere), flip that provider's own `enabled` flag once in `.claude/agents.json`. `codex-cli` (the local CLI) and `codex-cloud-bot` (the PR bot) are separate flags on purpose, since you may want to keep one running while pausing the other.
```

- [ ] **Step 5: Cross-reference from the failover section**

At the end of `## Failover and quota handling`'s bullet list in the same file, add one more bullet:

```markdown
- A provider disabled on purpose in `.claude/agents.json` follows the same rule as one that's hit a limit: fall through the role's configured chain, then these tiers — never silently drop the review step.
```

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `bash tests/bootstrap.test.sh`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add template/docs/DEVELOPMENT-PROCESS.md tests/bootstrap.test.sh
git commit -m "docs: reference .claude/agents.json from the Roles table and add Provider assignment"
```

---

### Task 4: Point `template/CLAUDE.md` and `template/AGENTS.md` at the config

**Files:**
- Modify: `template/CLAUDE.md`
- Modify: `template/AGENTS.md`
- Modify: `tests/bootstrap.test.sh`

- [ ] **Step 1: Write the failing assertions**

Add to `tests/bootstrap.test.sh`, near the other `grep` assertions:

```bash
grep -q ".claude/agents.json" "$kit/template/CLAUDE.md" || fail "template/CLAUDE.md doesn't reference agents.json"
grep -q ".claude/agents.json" "$t/AGENTS.md" || fail "installed AGENTS.md doesn't reference agents.json"
```

Note: check the **kit's own** `template/CLAUDE.md` source file, not `$t/CLAUDE.md` — the test's `$t/CLAUDE.md` is deliberately the pre-existing "existing" fixture from Task 1's skip-test and is never overwritten by bootstrap, so asserting against it would test the wrong thing. `$t/AGENTS.md` has no such fixture, so it does reflect the real installed content.

- [ ] **Step 2: Run it and confirm it fails**

Run: `bash tests/bootstrap.test.sh`
Expected: FAIL on one or both new assertions.

- [ ] **Step 3: Update `template/CLAUDE.md`**

Add a bullet to the "Non-negotiables" list, after the existing `pairing-with-codex-cli` bullet:

```markdown
- Roles have a default agent, but `.claude/agents.json` can reassign or disable any of them (including local LLMs) — check it before assuming Codex.
```

- [ ] **Step 4: Update `template/AGENTS.md`**

In the "Your roles" section's item 1, append a clause to the existing sentence. Change:

```markdown
1. **Reviewer:** local `codex review` and the PR bot ("@codex review") — but not on every change. Claude uses a risk-based review budget (`docs/DEVELOPMENT-PROCESS.md` → **Review budget**): you may not be invoked at all on low-risk changes, so don't assume your absence from a PR means the process was skipped.
```

to:

```markdown
1. **Reviewer:** local `codex review` and the PR bot ("@codex review") — but not on every change. Claude uses a risk-based review budget (`docs/DEVELOPMENT-PROCESS.md` → **Review budget**): you may not be invoked at all on low-risk changes, so don't assume your absence from a PR means the process was skipped — it may also mean `.claude/agents.json` reassigned that role to a different provider.
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `bash tests/bootstrap.test.sh`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add template/CLAUDE.md template/AGENTS.md tests/bootstrap.test.sh
git commit -m "docs: point installed CLAUDE.md/AGENTS.md at .claude/agents.json"
```

---

### Task 5: Rebrand the plugin/marketplace package

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: plugin name `agent-sdlc`, marketplace name `agent-sdlc-kit`. Consumed by Task 7's README install instructions.

- [ ] **Step 1: Update `plugin.json`**

Replace the full contents of `.claude-plugin/plugin.json`:

```json
{
  "name": "agent-sdlc",
  "version": "0.1.0",
  "description": "A pluggable-agent SDLC for Claude Code: Claude orchestrates and commits, and each role (implementation, review, PR gate) can be assigned to Codex, a specific Claude model, or a local LLM. GitHub issues hold the backlog, and a PR follow-up loop runs unattended until you review.",
  "author": {
    "name": "Alex Nykolaiszyn",
    "url": "https://github.com/anykolaiszyn"
  },
  "homepage": "https://github.com/anykolaiszyn/claude-codex-sdlc-kit",
  "repository": "https://github.com/anykolaiszyn/claude-codex-sdlc-kit",
  "license": "MIT",
  "keywords": ["codex", "code-review", "sdlc", "tdd", "github", "pull-requests", "workflow", "multi-agent", "local-llm"]
}
```

(Version stays `0.1.0` — bumping it is a release-time action per `CONTRIBUTING.md` → **Releases**, not part of this PR.)

- [ ] **Step 2: Update `marketplace.json`**

Replace the full contents of `.claude-plugin/marketplace.json`:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "agent-sdlc-kit",
  "description": "Claude orchestrates, and each SDLC role can be assigned to Codex, a Claude model, or a local LLM: a spec-first, test-first, PR-looped development process for Claude Code.",
  "owner": {
    "name": "Alex Nykolaiszyn",
    "url": "https://github.com/anykolaiszyn"
  },
  "plugins": [
    {
      "name": "agent-sdlc",
      "source": "./",
      "description": "Skills and commands to install and run a pluggable, multi-provider agent development process in any GitHub repo.",
      "version": "0.1.0",
      "license": "MIT",
      "category": "workflow",
      "keywords": ["codex", "code-review", "sdlc", "tdd", "github", "workflow", "local-llm"]
    }
  ]
}
```

- [ ] **Step 3: Validate the manifests**

Run: `for f in .claude-plugin/*.json; do python3 -m json.tool "$f" >/dev/null && echo "ok $f"; done`
Expected: `ok .claude-plugin/plugin.json` and `ok .claude-plugin/marketplace.json`.

Run: `claude plugin validate .`
Expected: no errors. (If the `claude` CLI isn't available in this environment, note that in the task's completion message instead of skipping the check silently.)

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: rename plugin package to agent-sdlc / agent-sdlc-kit"
```

---

### Task 6: Document provider/role customization in `docs/customizing.md`

**Files:**
- Modify: `docs/customizing.md`

- [ ] **Step 1: Replace the "Roles" section**

Replace:

```markdown
## Roles

Edit the Roles table in `docs/DEVELOPMENT-PROCESS.md`:
- **No Codex quota:** a Claude Haiku subagent implements the tasks whose code is in the plan, and a Claude Sonnet subagent does the local pre-PR review.
- **No Codex GitHub bot:** replace the PR gate with a local `codex review --base <base>` after each push, and post its findings on the PR yourself.
```

with:

```markdown
## Roles and providers

Each role in `docs/DEVELOPMENT-PROCESS.md`'s Roles table resolves through `.claude/agents.json` — edit that file, not the table, to change who does the work:
- **No Codex quota:** disable `codex-cli` (`"providers": {"codex-cli": {"enabled": false}}`); `implementation` and `pre_pr_review` fall through to their next configured provider (Claude Sonnet by default).
- **No Codex GitHub bot:** disable `codex-cloud-bot`; `pr_gate` then has nothing left in its chain unless you add a fallback (e.g. `["codex-cloud-bot", "claude-sonnet"]`), or leave it empty and post a local review on the PR yourself.
- **Pointing a role at a local LLM:** add an entry to `providers` with `"kind": "openai-http"`, a `base_url` and `model` (bootstrap asks for these once, under `LOCAL_LLM_BASE_URL`/`LOCAL_LLM_MODEL`, and writes them into the `local` provider), then list that provider's name in a role's chain — most usefully `pre_pr_review` or `task_review`. See `skills/pairing-with-local-llms/SKILL.md` for the adapter's gotchas (small context windows, review-only, no delegation). **Local LLM support is currently review-only: don't assign one to `implementation`.**
- Provider chains are fallback-ordered, first `enabled` entry wins. See `docs/DEVELOPMENT-PROCESS.md` → **Provider assignment** for the exact resolution rule.
```

- [ ] **Step 2: Verify**

Run: `grep -q "Roles and providers" docs/customizing.md && grep -q "openai-http" docs/customizing.md && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add docs/customizing.md
git commit -m "docs: explain role-to-provider assignment in customizing.md"
```

---

### Task 7: README, CHANGELOG, and final verification

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update README's opening paragraph**

In the paragraph starting "**Two AI agents, one disciplined process.**", after the sentence ending "...low-cost implementer when the task warrants it.", insert:

```markdown
 Every role — implementation, review, or the PR gate — can be reassigned to a different model, including a local one, or turned off if you're using that quota elsewhere.
```

- [ ] **Step 2: Update the "What gets installed in your repo" table**

Add two rows to the table (after the `docs/ROADMAP.md` row and after the `.claude/skills/pairing-with-codex-cli/` row respectively):

```markdown
| `.claude/agents.json` | Claude | Assigns each SDLC role to a provider (Codex, a Claude model, or a local LLM) and lets you disable any of them |
```

```markdown
| `.claude/skills/pairing-with-local-llms/` | Claude | A repo copy of the local-LLM review adapter, for teammates without the plugin |
```

- [ ] **Step 3: Update "Commands and skills"**

Add a row after the `pairing-with-codex-cli` skill row:

```markdown
| Skill | `pairing-with-local-llms` | How to run a review against a local OpenAI-compatible LLM (`run-local-llm.sh`) when a role is assigned to one |
```

- [ ] **Step 4: Update the install instructions**

Change:

```text
/plugin install claude-codex-sdlc@claude-codex-sdlc-kit
```

to:

```text
/plugin install agent-sdlc@agent-sdlc-kit
```

(The `/plugin marketplace add anykolaiszyn/claude-codex-sdlc-kit` line above it is unchanged — the GitHub repo path didn't move.)

- [ ] **Step 5: Update the "Customising" doc pointer**

Change:

```markdown
- [Customising](docs/customizing.md): the quality bar, timings, roles, and stacks other than Node
```

to:

```markdown
- [Customising](docs/customizing.md): the quality bar, timings, roles and providers (including local LLMs), and stacks other than Node
```

- [ ] **Step 6: Update CHANGELOG.md**

Under `## [Unreleased]`, append to the existing `### Added` list (don't create a new version section — that happens at release time per `CONTRIBUTING.md`):

```markdown
- `.claude/agents.json`: assigns each SDLC role (implementation, task review, pre-PR review, final review, PR gate) to a provider — Codex, a Claude subagent model, or a local OpenAI-compatible LLM — and lets any provider be disabled without breaking the process's failover rules.
- `pairing-with-local-llms` skill and `run-local-llm.sh`: runs a review against a local LLM endpoint (Ollama, LM Studio, vLLM, etc.) with the same log-to-disk/findings-only contract as `run-codex.sh`.
```

and add a new subsection right after it:

```markdown
### Changed
- Plugin renamed to `agent-sdlc` (marketplace `agent-sdlc-kit`) to reflect pluggable, multi-provider support; the GitHub repo path is unchanged.
```

- [ ] **Step 7: Run the full verification suite**

Run, in order, and confirm each passes:
- `bash tests/bootstrap.test.sh`
- `bash tests/run-local-llm.test.sh`
- `shellcheck scripts/*.sh tests/*.sh skills/pairing-with-codex-cli/run-codex.sh skills/pairing-with-local-llms/run-local-llm.sh`
- `for f in .claude-plugin/*.json; do python3 -m json.tool "$f" >/dev/null && echo "ok $f"; done`
- `claude plugin validate .`

- [ ] **Step 8: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: document provider assignment and the agent-sdlc rebrand in README/CHANGELOG"
```
