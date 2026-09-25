# Customising

## The quality bar (do this first)

The quality bar decides what counts as **blocking**, and blocking findings are the only ones fixed inside a PR. It lives in two places, so both agents apply it:
- `docs/ARCHITECTURE.md` → **Quality bar**, filled in during brainstorming
- `AGENTS.md` → **Review guidelines**, taken from the `REVIEW_PRIORITIES` answer

Examples:

| Project | Quality bar |
|---|---|
| Data visualisation | Every displayed number is accurate, nulls and partial totals are shown honestly, and the chart design rules are followed |
| Web API | No data loss, correct auth and permissions, backward-compatible responses, and correct error codes |
| CLI tool | Correct exit codes, no destructive default, and stable output formats |
| Library | Stable public API, documented behaviour, and no new runtime dependencies |

## Other stacks

Only four answers are specific to a stack:

| Stack | `TEST_CMD` | `CHECK_CMD` | `CODEX_TEST_CMD` (Windows) | `CODEX_CHECK_CMD` |
|---|---|---|---|---|
| Node/TS (vitest) | `npm test` | `npm run typecheck` | `npx.cmd vitest run` | `npx.cmd tsc --noEmit` |
| Python | `pytest` | `ruff check . && mypy .` | `python -m pytest` | `python -m ruff check .` |
| Go | `go test ./...` | `go vet ./...` | `go test ./...` | `go vet ./...` |
| Rust | `cargo test` | `cargo clippy -- -D warnings` | `cargo test` | `cargo clippy` |

On macOS or Linux, use the same commands for Codex as for yourself.

## Codex budget, model policy, and failover

The risk-tier table, the value-first model policy, the failover rules (transient error vs. quota exhaustion), and the requirement to state `Review budget: <tier> — <why>` in every PR all live in one place so they can't drift: **`docs/DEVELOPMENT-PROCESS.md`** → **Review budget** and **Failover and quota handling**. Both agents read that file every session; this page only covers what's specific to *tuning* it per project.

### Set your project's default here, not by editing prose

`docs/ARCHITECTURE.md` → **Review budget** (filled in during brainstorming, from the `REVIEW_BUDGET` bootstrap answer) is where a project states its own tolerance — for example, "review every PR regardless of size" for a small production API, or "skip Codex below one file changed" for an internal tool. `docs/DEVELOPMENT-PROCESS.md`'s table is the fallback for anything that field doesn't cover.

Principles this tuning should follow:
- Start with the smallest viable model and the smallest viable review; escalate on risk, not habit.
- Keep the independent reviewer only where the task genuinely warrants it — the goal is the best value combination for the risk, not "always use both agents."
- Some repos will use Codex on nearly everything; others only on high-risk work. Both are correct uses of the kit.

## Timings and limits

Change these in `docs/DEVELOPMENT-PROCESS.md` and in `skills/pairing-with-codex-cli/SKILL.md`, and keep the two in step:
- the wait between PR checks: **600 s**
- fix rounds before the loop stops and tags you: **3**
- retries per round on the 600 s cadence, shared by transient errors and silence: **1** — a usage-limit/quota response does **not** use this retry; it fails over immediately (see **Failover and quota handling** in `docs/DEVELOPMENT-PROCESS.md`)
- empty checks before the loop tags you: **3**

## Roles

Edit the Roles table in `docs/DEVELOPMENT-PROCESS.md`:
- **No Codex quota:** a Claude Haiku subagent implements the tasks whose code is in the plan, and a Claude Sonnet subagent does the local pre-PR review.
- **No Codex GitHub bot:** replace the PR gate with a local `codex review --base <base>` after each push, and post its findings on the PR yourself.

## Labels and milestones

`scripts/labels.sh` holds the label set. Unattended mode's eligibility rule matches on the label names `bug`, `edge-case` and `process`, so if you rename them, update the rule too.
