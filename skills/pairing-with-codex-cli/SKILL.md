---
name: pairing-with-codex-cli
description: Use when the OpenAI Codex CLI (`codex`) should review a branch, commit, or uncommitted changes; when Codex (CLI or the GitHub PR bot, chatgpt-codex-connector) has left review comments or findings to triage; when running the PR follow-up loop after posting "@codex review"; or when offloading a well-specified coding task to Codex to save Claude tokens.
---

# Pairing with the Codex CLI

## Overview

Claude orchestrates and owns every decision and every commit. Codex is an independent reviewer, and optionally an implementer, that spends the user's ChatGPT quota instead of Claude's. **Codex output is a claim, not evidence.** Verify every finding and every diff before acting on it.

## When to use

| Moment | Use | Why |
|---|---|---|
| Low-risk change (docs, comments, trivial refactor, tiny non-runtime cleanup) | Usually **No** review | The cost is rarely worth it |
| Medium-risk localized change | `review --base <PR base branch>` | Finds bug classes Claude reviewers miss without the full PR loop |
| Large uncommitted diff with real risk | `review --uncommitted` | Cheap second look before committing |
| Well-specified task with runnable tests and narrow scope | `exec` delegation | Moves implementation off Claude's quota when the task is bounded |
| Broad or judgment-heavy work | **No** delegation | Keep it with Claude |
| Every task in a subagent loop | **No** by default | About 5–10 min per run; it duplicates the per-task Claude review |

## Review budget

Use a risk-based budget, not a fixed default: skip Codex on low-risk changes, one targeted `review --base <base>` on medium-risk ones, the full review and PR loop on high-risk ones. The canonical risk-tier table (and the requirement to state `Review budget: <tier> — <why>` in the PR) is in `docs/DEVELOPMENT-PROCESS.md` → **Review budget** — read it there rather than re-deriving the tiers here. Always review the changed surface, not the whole branch; for stacked PRs, review only the delta against the relevant base branch.

## Running it

Always use `run-codex.sh` (in this skill's directory). It saves the full log to disk and prints only the findings or final message. **Never read the raw log.** It is thousands of lines.

```bash
S=.claude/skills/pairing-with-codex-cli   # repo copy; if absent, use this skill's base directory
"$S/run-codex.sh" review --base <PR base branch>    # usually main; the parent branch when stacked; run in background
"$S/run-codex.sh" exec brief.md -C <repo-or-worktree>
```

Gotchas:
- Exit **3** means an exhausted quota: apply **Limit handling and failover** below without re-grepping the log. Exit **1** is another failure; generic transient rate limits retain that status. Exit **0** means success; **2** means an unknown wrapper mode.
- `review --base/--uncommitted/--commit` **cannot take custom instructions**. Passing a prompt errors out.
- Never paste a diff into a prompt. `review` reads git itself.
- **Windows:** Codex runs commands through PowerShell, where `npx`/`npm` `.ps1` shims are blocked. Tell Codex to use `npx.cmd` / `npm.cmd`.
- Check `codex <cmd> --help` before using any flag. Don't guess (`exec` has no `--ask-for-approval`).
- Reviews take minutes. Use the Bash tool's background option (`run_in_background`), **not** a shell `&` (a detached job never reports back). Do other work meanwhile.

## Worktree setup

Use this skill's installed base directory when the worktree has no repo copy. If a repo copy is needed, fetch and copy only the missing skill files from the committed `origin/<default-branch>` version (usually `origin/main`), never from a sibling worktree's working tree. Do not overwrite existing files or stage unrelated skill changes. If the default branch has no committed copy, use the installed plugin copy instead.

For stacked PRs, follow `docs/DEVELOPMENT-PROCESS.md` → **Stacked branches: drain before merging** before handing a parent PR to the user, and audit for stranded work after merges. Partial issue work uses `Closes part of #N`; only the PR completing the issue uses `Closes #N`.

## Triage every finding (required)

For each finding:
1. **Reproduce it** with a small probe (a script or focused test) before believing it.
2. Record a verdict: **Valid / Invalid / Unclear**, with the probe output.
3. **Valid and blocking** (see below): write a failing test first, then fix. Check sibling code for the same bug class. **Valid but not blocking:** open a backlog issue instead of fixing it.
4. **Invalid:** reply with the evidence. Never "fix" it anyway.
5. **Unclear:** probe further, or ask the user. Don't drop it silently, and don't fix it on faith.

Severity and ease of fixing do not decide whether a finding is real. The probe does.

## Delegating a task to Codex

Write the brief as a file. Its parts, in order:
1. **The bug or requirement**, with a concrete failing input.
2. **Required behaviour**, plus what must not change.
3. **Test-first steps:** add a failing test, confirm it fails, implement.
4. **Exact verification commands** (Windows: `npx.cmd vitest run`, `npx.cmd tsc --noEmit`).
5. **"Do NOT commit, push, or touch git history."**
6. **Final message contract:** files changed, the failing-test (RED) line, the full-suite (GREEN) line, the typecheck result, and concerns.

Then Claude reviews the diff like any subagent's work and **reruns the tests itself**. If there are findings, send them back as a new brief (one fix round). Claude commits, noting "Implemented by Codex CLI" in the message.

Delegate only when Codex can run the tests. Confirm that once per machine with a 15-second `exec` that only runs the test command.

## Blocking or backlog

A **blocking** finding is one that gives wrong output for data or behaviour the milestone ships, crashes, breaks the spec, or breaches the project's quality bar (`docs/ARCHITECTURE.md`). Fix it in the PR, test-first. Any other **valid** finding becomes a backlog GitHub issue with these sections: What / Repro / Expected / Found by / Proposed fix / Suggested milestone. Reply in the thread with its link. Chasing every edge case in one PR never ends.

## PR follow-up loop

After pushing, post "@codex review" (a new PR is reviewed automatically), then self-schedule a wake-up 600 seconds later. On waking, check for Codex's response to the head commit:
- a Codex review whose `commit_id` is the head commit → triage **that review's** comments (match `pull_request_review_id`); never select comments by their own `commit_id` (GitHub moves old ones forward). Also triage any Codex review submitted since the last check, on any commit
- a 👍 reaction → no findings
- "Something went wrong" → re-post (uses the round's single retry)
- nothing yet → wait again; after the second empty check re-post "@codex review" if the single retry is unused (covers a lost automatic review); after three, tag the user and move on
- one retry per round, shared by both paths; it resets when a new blocking fix is pushed

**Limit handling and failover (required):** see `docs/DEVELOPMENT-PROCESS.md` → **Failover and quota handling** for the full rule. Summary:
- A **transient error or silence** ("Something went wrong", or nothing yet) uses this loop's normal retry: one per round, on the existing 600-second cadence.
- A **usage-limit / quota-exhausted** response is a different failure shape: quota resets run hours to days, not 600 seconds, so do not keep polling this loop's cadence waiting on it. Fall back immediately, for this round, to a Claude-equivalent review (or the CLI, if only the bot is out, or vice versa), note the fallback in the PR, and try Codex again next PR or session.
- Either way: never silently skip the review step, and never force a merge with no human approval. A limit pauses or reroutes the check; it doesn't erase it.

**End of every triage round (required checklist, even when your summary is short):**
- [ ] **If a blocking fix was pushed:** post "@codex review" on the PR, then self-schedule the next wake-up 600 seconds later (`ScheduleWakeup`) before ending your turn.
- [ ] **If no blocking fix was pushed** (only backlog issues or invalid findings): the round meets the stopping rule. Post the summary comment, and don't trigger another review.
- [ ] **If the change was low-risk and already covered by tests:** do not re-trigger a full review cycle just because a PR is open; keep the loop narrow and stop early.
- [ ] **If review services are unavailable:** apply the transient-vs-quota split above, preserve the human approval gate, and resume later when limits clear.

**Stop** when Codex reacts 👍, or a round has no blocking findings, or after 3 fix rounds (then tag the user). Finish with one PR summary comment: the review budget tier and reason (from the PR description), fixes with commits, issues opened, invalid findings, and any blocking findings still open (listed first); if a quota failover happened, name it. Then tag the user (@mention them in the summary comment, assign the PR to them, and send a push notification), then move on to the next available issue (see Unattended mode). Never stop to ask.

## Common mistakes

| Mistake | Fix |
|---|---|
| `codex exec "review the diff…"` | Use `codex review` |
| `cat` / Read of Codex output | Use `run-codex.sh`, which prints findings only |
| Acting on findings unverified | Probe each one first |
| Delegated fix with no test | Brief requires test-first plus a RED line |
| Trusting Codex's "tests pass" | Rerun them yourself |
| Letting Codex commit | Brief forbids git; Claude commits |
