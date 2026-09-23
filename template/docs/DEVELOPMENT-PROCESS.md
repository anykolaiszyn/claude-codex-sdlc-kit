# Development process

How work gets done in this repo. Claude orchestrates; Codex is a second reviewer and a task implementer. Both agents read this file.

## The loop

1. **Pick work.** Read `docs/ROADMAP.md`, then `gh issue list --milestone "<current milestone>"`. Take the next open issue.
2. **Design.** `superpowers:brainstorming`, then a spec in `docs/superpowers/specs/`, approved by the user.
3. **Plan.** `superpowers:writing-plans`. When the plan is written, create one GitHub issue per plan task and link them from the milestone's overview issue.
4. **Build.** `superpowers:subagent-driven-development` on a feature branch (never `{{MAIN_BRANCH}}`), using the roles below.
5. **Before the PR.** Local `codex review --base <the PR's base branch>` (usually `{{MAIN_BRANCH}}`; the parent branch when stacked) via the `pairing-with-codex-cli` skill's `.claude/skills/pairing-with-codex-cli/run-codex.sh`, triaged below. Then the final whole-branch Claude review and its single fix wave.
6. **PR.** The body lists `Closes #N` for every issue the branch completes. Run the PR follow-up loop until it stops.
7. **Merge** by the user. The same PR ticks off finished items in `docs/ROADMAP.md`.

## Roles

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

Rules everywhere:
- Only Claude commits and pushes. Every commit ends with the attribution line from Claude Code's system prompt. Codex-written code is noted "Implemented by Codex CLI" in the commit body.
- On Windows, Codex runs commands through PowerShell, where `.ps1` shims are blocked: briefs say `npx.cmd` / `npm.cmd`.
- No Codex review per task: it takes about 5–10 minutes and duplicates the per-task Claude review.

## Triage

Every finding, from any reviewer:
1. **Reproduce it** with a probe (a small script or focused test).
2. Record **Valid / Invalid / Unclear** with the probe output.
3. Classify each Valid finding:
   - **Blocking:** wrong output for data or behaviour the milestone ships, a crash, a spec violation, or a breach of the quality bar in `docs/ARCHITECTURE.md`. Fix it in the PR, test-first. Reply in the thread with the commit.
   - **Edge case / non-blocking:** valid, but outside the milestone's data or scope, belonging to a later milestone, or polish. Open a backlog issue and reply with its link.
4. **Invalid:** reply with the evidence. **Unclear:** probe further or ask the user; never drop it silently.

## PR follow-up loop

Runs in the Claude Code session with self-scheduled wake-ups.
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
6. On stopping, post one PR summary comment: fixed findings with commits, backlog issues opened, invalid findings, and any blocking findings **still open** (listed first, if the 3-round cap was hit). Then tag the user (@mention them in the summary comment, assign the PR to them, and send a push notification), then move on to the next available issue (see Unattended mode). Never stop to ask.

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
4. Pre-PR local Codex review, then the PR follow-up loop, then tag the user, then pick the next issue.
5. **Stop picking** when no eligible issue remains; tell the user which `feature` or `needs-decision` issues are waiting for them.

## Starting a session

1. `git fetch` and `git status`. Confirm the branch; never start work on `{{MAIN_BRANCH}}`.
2. Read `docs/ROADMAP.md` (if it's missing on this branch, use `gh issue list --label feature --search "overview in:title"`), then run `gh issue list --milestone "<current milestone>"`.
3. `gh pr list`. If an open PR has unresolved Codex comments, resume the PR follow-up loop first.
4. Continue the superpowers process from wherever the picked issue stands.
