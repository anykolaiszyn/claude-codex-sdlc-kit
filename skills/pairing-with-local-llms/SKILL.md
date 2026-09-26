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
