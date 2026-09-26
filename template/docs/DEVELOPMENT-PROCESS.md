# Development process

How work gets done in this repo. Claude orchestrates; Codex is a second reviewer and a task implementer. Both agents read this file.

## The loop

1. **Pick work.** Read `docs/ROADMAP.md`, then `gh issue list --milestone "<current milestone>"`. Take the next open issue.
2. **Design.** `superpowers:brainstorming`, then a spec in `docs/superpowers/specs/`, approved by the user.
3. **Plan.** `superpowers:writing-plans`. When the plan is written, create one GitHub issue per plan task and link them from the milestone's overview issue.
4. **Build.** `superpowers:subagent-driven-development` on a feature branch (never `{{MAIN_BRANCH}}`), using the roles below.
5. **Before the PR.** Classify the change's risk tier (see **Review budget** below) and review accordingly: low-risk work can skip Codex entirely, medium-risk work gets a focused local `codex review --base <the PR's base branch>` (usually `{{MAIN_BRANCH}}`; the parent branch when stacked) via the `pairing-with-codex-cli` skill's `.claude/skills/pairing-with-codex-cli/run-codex.sh` — or the `pre_pr_review` role's other configured provider, see **Provider assignment** — and high-risk work gets the full review plus the usual follow-up loop. State the tier and why in the PR description. Then perform the final whole-branch Claude review and its single fix wave.
6. **PR.** The body lists `Closes #N` for every issue the branch completes. Run the PR follow-up loop until it stops.
7. **Merge** by the user. The same PR ticks off finished items in `docs/ROADMAP.md`.

## Roles

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

Rules everywhere:
- Only Claude commits and pushes. Every commit ends with the attribution line from Claude Code's system prompt. Codex-written code is noted "Implemented by Codex CLI" in the commit body.
- On Windows, Codex runs commands through PowerShell, where `.ps1` shims are blocked: briefs say `npx.cmd` / `npm.cmd`.
- Use Codex by risk and scope, not by default (see **Review budget** below). Review only the changed surface area; don't run a broad branch review when a single subsystem or a small delta changed.
- If the task needs broad context, judgment or multi-file trade-offs, keep it with Claude instead of delegating it to Codex.
- The default is a value-first model policy: start with the cheapest model that can validate the change, then escalate to a stronger model only when risk, ambiguity, or impact rises.
- The process must remain universal. A repo may use Codex heavily, lightly, or only on high-risk work; the deciding factor is the risk-adjusted value of the review, not a blanket rule.
- The PR remains the human-in-the-loop gate. Codex can suggest and review, but the final merge is always a person-approved action.
- If a review or PR bot hits a limit, see **Failover and quota handling** below. Never silently drop the review step.

## Provider assignment

Each role in the table above resolves to a provider through `.claude/agents.json`: an ordered list of provider names per role, and an `enabled` flag on each provider (see the file itself for the schema). Claude resolves a role by walking its list and taking the first entry with `enabled: true`; for a `local` (OpenAI-compatible HTTP) provider, an unreachable endpoint at call time counts the same as "not usable" and falls through to the next entry. If nothing in a role's chain is usable, apply the **Review budget** and **Failover and quota handling** rules below exactly as if the default provider had hit its limit.

A repo with no `.claude/agents.json` behaves exactly as this table's defaults describe — the file is additive, not required.

To pause a provider without editing every role that uses it (for example, to stop spending a ChatGPT quota you're using elsewhere), flip that provider's own `enabled` flag once in `.claude/agents.json`. `codex-cli` (the local CLI) and `codex-cloud-bot` (the PR bot) are separate flags on purpose, since you may want to keep one running while pausing the other.

## Review budget

Risk tier decides how much independent review a change gets, for both Codex delegation and the pre-PR/PR-gate reviews. The tier is not just an inline judgment call: **state it, with a one-line reason, in the PR description** (`Review budget: <tier> — <why>`), so a human skimming the PR can see and challenge the call instead of it being invisible.

| Risk tier | Typical work | Codex use | Claude use |
|---|---|---|---|
| Low | Docs, comments, formatting-only refactors, tiny non-runtime cleanup | Skip, unless the change touches a public contract or user-visible behaviour | Local checks and final review |
| Medium | One module, one feature area, or a localized bug fix | One focused `codex review --base <base>` or a single bounded `exec` brief, scoped to the changed files | Design, scope, and final sign-off |
| High | Auth, permissions, data migrations, contracts, crypto, or anything touching multiple subsystems | Full review and the standard PR follow-up loop | Final branch review, approvals, and risk triage |

For stacked PRs, review the delta against the relevant base branch; don't repeat a full review of already-reviewed code. A project can tune its own default tolerance in `docs/ARCHITECTURE.md` → **Review budget**, filled in during brainstorming; this table is the fallback when that field doesn't cover a case.

## Failover and quota handling

A transient hiccup and an exhausted quota need different responses; conflating them either wastes a check on a quota that won't reset for hours, or stalls the loop waiting on it.

- **Transient error or silence** (a bot glitch, a dropped response): use the PR follow-up loop's normal retry — one retry per round, 600 seconds apart. Keep polling on that cadence; it's sized for a minutes-scale hiccup, and it's covered in the PR follow-up loop below.
- **Usage limit / quota exhausted** (the CLI or bot reports it's out of quota): quota resets run hours to days, not minutes. Do not keep polling on the 600-second cadence. Fall back immediately, for this round, to a Claude-equivalent review (or the other side's local/CLI review, if only one of CLI/bot is out). Note the fallback in the PR. Try Codex again on the next PR or session, not within this wait loop.
- Either way: a limit pauses or reroutes the review, it never removes it, and it never authorizes a merge without the human.
- A provider disabled on purpose in `.claude/agents.json` follows the same rule as one that's hit a limit: fall through the role's configured chain, then these tiers — never silently drop the review step.

## Triage

Every finding, from any reviewer:
1. **Reproduce it** with a probe (a small script or focused test).
2. Record **Valid / Invalid / Unclear** with the probe output.
3. Classify each Valid finding:
   - **Blocking:** wrong output for data or behaviour the milestone ships, a crash, a spec violation, or a breach of the quality bar in `docs/ARCHITECTURE.md`. Fix it in the PR, test-first. Reply in the thread with the commit.
   - **Edge case / non-blocking:** valid, but outside the milestone's data or scope, belonging to a later milestone, or polish. Open a backlog issue and reply with its link.
4. **Invalid:** reply with the evidence. **Unclear:** probe further or ask the user; never drop it silently.

## PR follow-up loop

Runs in the Claude Code session with self-scheduled wake-ups. Which provider actually performs the gate is decided by the `pr_gate` role in `.claude/agents.json` (default: the Codex cloud bot, "@codex review"); the steps below describe that default path — see **Provider assignment**. If `pr_gate` resolves to no usable provider, apply the **Review budget**/**Failover and quota handling** rules instead of silently skipping the gate.
1. After a push, post "@codex review", unless the PR was just opened (Codex reviews new PRs automatically).
2. Wake up **600 seconds** later.
3. Look for Codex's response to the current head commit:
   - a Codex review whose `commit_id` is the head commit → triage **that review's** inline comments (match each comment's `pull_request_review_id` to the review's `id`). Don't select comments by their own `commit_id`: GitHub moves an old comment's `commit_id` forward when its lines are unchanged. Also check for any Codex review submitted since the last triage, on any commit;
   - a 👍 reaction on the triggering comment → no findings;
   - a "Something went wrong" comment → re-post "@codex review" (this uses the round's **single retry**), then wait 600 seconds again;
   - nothing yet → wait 600 seconds again. After the second empty check, re-post "@codex review" if the round's single retry is unused (this also covers an automatic review on a new PR that never appears). After three empty checks, tag the user and move on.
   - Each round has **one retry**, shared by the error and silence paths; it resets when a new blocking fix is pushed.
4. If a blocking fix was pushed: post "@codex review" and go back to step 2. If the round only produced backlog issues or invalid findings, it has met the stopping rule; go to step 6.
5. **Stop** when Codex reacts 👍, or a round has no blocking findings, or after 3 fix rounds (then tag the user).
6. On stopping, post one PR summary comment: the review budget tier and reason (from the PR description), fixed findings with commits, backlog issues opened, invalid findings, and any blocking findings **still open** (listed first, if the 3-round cap was hit). If a quota failover happened, say so and name the fallback used. Then tag the user (@mention them in the summary comment, assign the PR to them, and send a push notification), then move on to the next available issue (see Unattended mode). Never stop to ask.

## Issues and roadmap

- **Milestones:** one GitHub milestone per roadmap row (`M1 — …`, `M2 — …`). An issue with no milestone is in the **backlog**.
- **Labels:**
  - type: `bug`, `edge-case`, `feature`, `process`
  - source: `from-codex`, `from-review`
  - status: `blocked`, `needs-decision`
- **Dependencies:** an issue that needs other work first says `Depends on #N` in its body (and gets the `blocked` label while #N is open).
- **Every discovered edge case or follow-up gets a backlog issue**, with these sections:
  - What
  - Repro (probe and actual output)
  - Expected
  - Found by / where (reviewer, PR, file:line)
  - Proposed fix
  - Suggested milestone
- **Milestone overview issue:** the goal, and the brief's acceptance criteria as a checklist. Task issues are linked in once the milestone's plan exists.
- **`docs/ROADMAP.md`:** one section per milestone with its status, overview-issue link and completion notes. It's updated in the PR that completes the work. The issues are the source of truth.

## Unattended mode

When a PR's loop stops, Claude continues with the next available issue instead of waiting.
1. **Eligible:** open issues labelled `bug`, `edge-case` or `process`, with no `blocked` or `needs-decision` label and no open `Depends on #N`. Take current-milestone issues first, then the backlog in the order bugs, edge cases, process. Never `feature` issues or milestone overviews: they are architectural and need the user in brainstorming. Leave those for the user.
2. **Design approval moves to the PR.** Post the short design (approach, files, tests) as a comment on the issue, repeat it in the PR description, and build test-first. The user's PR review is the approval.
3. **Branching:** start the issue's branch from the branch that holds the code it changes. While that code is only in an open PR, stack on that PR's branch (the new PR targets it); GitHub retargets it to `{{MAIN_BRANCH}}` when the base PR merges. Name branches `issue/<N>-<slug>`; the PR body says `Closes #N`.
4. Pre-PR review (per the `pre_pr_review` role) and the PR follow-up loop (per the `pr_gate` role — see **Provider assignment**), then tag the user, then pick the next issue.
5. **Stop picking** when no eligible issue remains; tell the user which `feature` or `needs-decision` issues are waiting for them.

## Starting a session

1. `git fetch` and `git status`. Confirm the branch; never start work on `{{MAIN_BRANCH}}`.
2. Read `docs/ROADMAP.md` (if it's missing on this branch, use `gh issue list --label feature --search "overview in:title"`), then run `gh issue list --milestone "<current milestone>"`.
3. `gh pr list`. If an open PR has unresolved Codex comments, resume the PR follow-up loop first.
4. Continue the superpowers process from wherever the picked issue stands.
