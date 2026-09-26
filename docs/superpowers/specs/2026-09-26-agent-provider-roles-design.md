# Agent provider roles — design

**Status:** approved in chat, pending written-spec review
**Depends on:** nothing (extends the current kit in place)
**Followed by:** a second spec for specialist roles + a project role scanner (out of scope here; see **Non-goals**)

## Context

Today the kit hardwires two agents into fixed positions: Claude Code orchestrates everything, and the OpenAI Codex CLI/cloud bot is the only reviewer/implementer it can delegate to. `template/docs/DEVELOPMENT-PROCESS.md`'s Roles table and `skills/pairing-with-codex-cli/` assume "Codex" by name throughout.

The goal is to generalize this into "**Agent SDLC Kit**": each SDLC role gets an assignable, swappable provider — including local LLMs running on the user's own machine — and any provider can be toggled off (e.g. to stop spending a ChatGPT quota that's in use elsewhere) without breaking the process's guarantees (every finding still probed, human still merges, failover rules still apply).

## Goals

- Every fixed SDLC role (`implementation`, `task_review`, `pre_pr_review`, `final_review`, `pr_gate`) can be assigned to a provider, chosen from a per-repo config file, not hardcoded in the docs.
- A generic **local LLM** provider kind works against any OpenAI-compatible HTTP endpoint (Ollama, LM Studio, vLLM, llama.cpp server, etc.) — no per-tool-specific integration needed.
- A provider can be **disabled** with one boolean flip, and every role that lists it falls through to its next configured provider, or to the existing risk-tier skip/failover rules if nothing is left.
- Repos that installed the kit before this change keep working **exactly as they do today** if they never add the new config file — this is additive, not a breaking migration.
- The plugin's package identity is renamed to reflect the broader scope (`agent-sdlc` / `agent-sdlc-kit`), without touching the GitHub repo name or its clone/marketplace-add URL.

## Non-goals

- **Local LLMs performing `implementation`.** A local model assigned to implementation would need to emit a patch and have something apply it to the working tree with no test-first guardrail beyond what the model itself claims — that's meaningfully riskier than review, and out of scope here. The config format doesn't prevent someone from wiring it up by hand, but the kit doesn't build or support it in this pass. `implementation`'s provider choices stay `codex-cli` and `claude-subagent`.
- **Specialist/focused roles** (a "security" or "frontend" reviewer scoped by path globs) and the **project role scanner** that proposes them. That's Spec 2, built on top of this file's schema, and is brainstormed separately.
- Any change to Codex's own mechanics, triage rules, or the PR follow-up loop's timing. `pairing-with-codex-cli` is referenced, not modified.
- A dispatcher script that resolves roles programmatically. The only consumer of `.claude/agents.json` right now is Claude itself, reading it directly each session — a script that also decides who-does-what would just be a second, redundant decision path.

## Config file: `.claude/agents.json`

Installed by `scripts/bootstrap.sh` like the rest of `template/`, and readable by any text editor. Two top-level maps:

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

**Provider kinds** (fixed enum for this pass — new kinds are additive later, not a redesign):

| Kind | Fields | Meaning |
|---|---|---|
| `codex-cli` | none beyond `enabled` | Local `codex` binary via `pairing-with-codex-cli`'s `run-codex.sh`. |
| `codex-cloud-bot` | none beyond `enabled` | The GitHub PR bot triggered by "@codex review". Disabling it means the PR follow-up loop never posts that comment for this repo. |
| `claude-subagent` | `model` (`sonnet`\|`opus`\|`haiku`) | An `Agent` tool call with that model. Always "available" — no reachability concern. |
| `openai-http` | `base_url`, `model` | A generic OpenAI-compatible `/chat/completions` endpoint, via the new `run-local-llm.sh` (see below). |

**Roles** are the fixed five above — this pass does not add new role keys. Each role's value is an ordered list of provider *names* (keys into `providers`), acting as a fallback chain.

## Role resolution and toggle semantics

Claude resolves a role by walking its `providers` list and taking the first entry whose provider has `enabled: true`. For `openai-http`, a connection failure at call time is treated the same as "not usable" (mirrors Codex's existing exit-code-3 "quota exhausted" signal) and Claude falls through to the next entry in the chain. If nothing in the chain is usable, apply the **existing** risk-tier/failover rules already in `DEVELOPMENT-PROCESS.md` (skip low-risk work, escalate to a Claude-inline pass for anything the quality bar requires, note the fallback in the PR). This spec does not introduce a second decision tree — it gives the existing one a config-driven first choice instead of a hardcoded name.

`enabled` lives on the **provider**, not on each role's list entry: flipping `providers.codex-cli.enabled` to `false` once removes Codex CLI from every role that lists it in the same edit. `codex-cli` and `codex-cloud-bot` are separate flags on purpose — a user may want to keep the free automatic PR-bot review running while pausing their own local CLI usage, or vice versa.

## New skill: `pairing-with-local-llms`

Mirrors `pairing-with-codex-cli`'s shape and installs the same way (`bootstrap.sh` copies it into `.claude/skills/pairing-with-local-llms/`, `chmod +x` its script).

`run-local-llm.sh` contract (same exit-code convention as `run-codex.sh`, so triage/failover logic reads it identically regardless of provider):
- `run-local-llm.sh review --base <base>` — builds the diff itself (`git diff <base>...HEAD`), wraps it in a review prompt asking for the same blocking/edge-case-shaped findings the kit expects elsewhere, POSTs it to the configured provider's `base_url`/`model` via `curl`.
- `run-local-llm.sh review --uncommitted` / `--commit <sha>` — same idea, different git diff source, matching `run-codex.sh`'s existing modes.
- Writes the full raw HTTP response to a log file on disk; **prints only the extracted findings to stdout** — never the raw log, same rule as `run-codex.sh`.
- Exit **0**: request succeeded, findings printed (possibly none). Exit **1**: reachable but malformed/failed response. Exit **3**: connection refused / endpoint unreachable — the "unavailable" signal that makes Claude fall through the role's provider chain.
- No `exec`/delegation mode in this pass (see **Non-goals**).

The skill's SKILL.md documents: running it, its gotchas (local models typically have smaller context windows — keep diffs scoped; no quota to exhaust, but availability isn't guaranteed either), and reuses `pairing-with-codex-cli`'s triage section by reference rather than duplicating it (every finding is still a claim, not evidence, regardless of which provider produced it).

## Changes to existing files

- **`template/docs/DEVELOPMENT-PROCESS.md`**: Roles table's "Who" column changes from hardcoded names to "the role's configured provider (default: `<current default>`)"; new **"Provider assignment"** section (parallel to the existing "Review budget" section) states the resolution/toggle rule above, and cross-references it from **Failover and quota handling** (a role resolving to no usable provider follows that section's fallback rules, whether the cause was a toggle or an outage).
- **`scripts/bootstrap.sh`**: two new `ask()` calls, `LOCAL_LLM_BASE_URL` (default empty) and `LOCAL_LLM_MODEL` (default empty, only meaningful if a base URL was given); a derived `LOCAL_LLM_ENABLED` (`true` if `LOCAL_LLM_BASE_URL` is non-empty, else `false`) computed before the template fill step; installs `.claude/agents.json` from a new `template/.claude/agents.json`; a second `install_tree` call for `skills/pairing-with-local-llms/` into `.claude/skills/pairing-with-local-llms/`, plus its `chmod +x`.
- **`tests/bootstrap.test.sh`**: asserts `.claude/agents.json` and `.claude/skills/pairing-with-local-llms/{SKILL.md,run-local-llm.sh}` are installed; asserts `{{LOCAL_LLM_*}}` placeholders are filled (including the derived boolean, both when a base URL is supplied and when it's left empty); the existing "second run is a no-op" and "never overwrites" checks extend to the new files without new logic.
- **New `tests/run-local-llm.test.sh`**: mirrors `tests/run-codex.test.sh`'s mocked-binary approach, but stubs a local HTTP listener instead of a `codex` binary, exercising the 0/1/3 exit-code contract.
- **`docs/customizing.md`**: new section on editing `.claude/agents.json` — reassigning a role, adding a provider, and pointing `base_url` at a local Ollama/LM Studio/vLLM server.
- **`template/CLAUDE.md`, `template/AGENTS.md`**: one line each pointing at `.claude/agents.json` as the source of truth for who does a given role, before assuming Codex.
- **`README.md`**: add `.claude/agents.json` to the "What gets installed" table; mention local-LLM support and per-role provider toggles in the Why/How-it-works framing; update the install command's plugin name (see **Rebrand**).

## Rebrand

- `.claude-plugin/plugin.json`: `name` → `agent-sdlc`; `description` updated to mention pluggable/local providers alongside Codex.
- `.claude-plugin/marketplace.json`: top-level `name` → `agent-sdlc-kit`; `plugins[0].name` → `agent-sdlc`; descriptions updated to match.
- The GitHub repo path (`anykolaiszyn/claude-codex-sdlc-kit`) is **unchanged** — `/plugin marketplace add anykolaiszyn/claude-codex-sdlc-kit` stays the same. Only the install half changes: `/plugin install agent-sdlc@agent-sdlc-kit`.
- `CONTRIBUTING.md`'s release section (bump `version` in both manifests) is unaffected in mechanics, just the names it refers to.

## Backward compatibility

A repo that bootstrapped before this change has no `.claude/agents.json`. Its absence is not an error: Claude falls back to the exact behavior documented today (Codex CLI/cloud bot for review roles, Codex `exec`/Claude subagents for implementation, per the existing Roles table prose) with no functional change until the repo re-runs `/sdlc-init` or hand-adds the file. `bootstrap.sh`'s existing "never overwrite" rule means re-running it on an already-installed repo only adds the new file; it does not touch anything the repo customized.

## Testing plan

- `bash tests/bootstrap.test.sh` — extended per above; must still pass its existing assertions unmodified in intent (no overwrite, idempotent second run, every placeholder filled).
- `bash tests/run-codex.test.sh` — unchanged, must still pass (proves the existing Codex contract wasn't disturbed).
- New `bash tests/run-local-llm.test.sh` — the 0/1/3 exit-code contract against a mocked local endpoint.
- `shellcheck scripts/*.sh tests/*.sh skills/pairing-with-codex-cli/run-codex.sh skills/pairing-with-local-llms/run-local-llm.sh`
- `claude plugin validate .` — must still pass after the manifest renames.
- Manual smoke check: bootstrap a scratch repo with a real local Ollama endpoint configured, run `run-local-llm.sh review --uncommitted` against a trivial diff, confirm findings print and the raw response lands in the log file, not stdout.
