# Manual setup guide

This guide sets the kit up without the plugin, or explains what `/sdlc-init` does for you.

## 1. One-time machine setup

| Need | Install / check |
|---|---|
| Claude Code | `claude --version` |
| The superpowers plugin | In Claude Code: `/plugin` → install `superpowers` from `claude-plugins-official` |
| Codex CLI (ChatGPT plan) | `npm i -g @openai/codex`, then `codex login`, then `codex --version` (0.156 or later) |
| GitHub CLI | `gh auth login`, then `gh auth status` |
| Codex PR bot | Enable "Code review" for the repo at chatgpt.com/codex → Settings. Once enabled, it reviews new PRs and answers `@codex review`. |
| Bash + Python | Git Bash on Windows runs the scripts. `python` must be on `PATH`. |

If you don't use the plugin, you can still make the skill available to every project, not just repos that have the kit installed:
```bash
cp -r skills/pairing-with-codex-cli ~/.claude/skills/
```
The in-repo copy wins when both exist.

## 2. Install into a project

```bash
git clone https://github.com/anykolaiszyn/claude-codex-sdlc-kit && cd claude-codex-sdlc-kit
scripts/bootstrap.sh ../MyProject --labels --milestone "M1 — First usable slice"
```

The script asks for the project name, a pitch, the default branch, and the test and check commands. It asks separately for the commands Codex runs; on Windows they must use `npx.cmd`/`npm.cmd`. It also asks for the review priorities. To skip the prompts, set these environment variables:

```bash
PROJECT_NAME=MyProject PROJECT_PITCH="A tool that …" MAIN_BRANCH=main \
TEST_CMD="npm test" CHECK_CMD="npm run typecheck" \
CODEX_TEST_CMD="npx.cmd vitest run" CODEX_CHECK_CMD="npx.cmd tsc --noEmit" \
REVIEW_PRIORITIES="correctness of user-visible output, data loss, security, and validation gaps." \
M1_TITLE="First usable slice" scripts/bootstrap.sh ../MyProject --labels
```

What the script does:
- Copies `template/` into the repo and fills in the `{{PLACEHOLDERS}}`. It **never overwrites** an existing file; it lists the skipped files so you can merge them by hand.
- Adds `.superpowers/` to `.gitignore`. Worktrees and plan ledgers live there.
- With `--labels`, creates the labels:
  - type: `bug`, `edge-case`, `feature`, `process`
  - source: `from-codex`, `from-review`
  - status: `blocked`, `needs-decision`
- With `--milestone`, creates the first GitHub milestone.

For a stack other than Node, change the four commands, for example `pytest`, `ruff check .`, or `go test ./...`. Nothing else in the kit is tied to a language.

Then commit the files on a branch and open a PR. Claude can do this in the first session.

## 3. Check Codex once per machine and repo

```bash
cd ../MyProject
S=.claude/skills/pairing-with-codex-cli
echo "Run the test command ($CODEX_TEST_CMD) and report the summary line. Do not edit files." > /tmp/probe.md
"$S/run-codex.sh" exec /tmp/probe.md -C .
```
If Codex can't run the tests, skip Codex implementation in this repo. The roles table's fallback covers it: a Claude Haiku or Sonnet subagent does the work instead. Reviews still work.

## 4. First session: brainstorm

Open Claude Code in the repo and paste:

> Read CLAUDE.md and docs/DEVELOPMENT-PROCESS.md. We're starting this project from scratch. Use superpowers:brainstorming to shape the brief in docs/ARCHITECTURE.md (users, fixed stack, non-goals, milestones, and the quality bar that defines "blocking"). Then write the spec, and once I approve it, create a milestone overview issue for each milestone and update docs/ROADMAP.md. Stop at each approval gate.

Here's what happens:
1. **Brainstorming:** one question at a time. You approve the design.
2. **Spec** in `docs/superpowers/specs/`. You approve it.
3. **Plan** in `docs/superpowers/plans/`. One task issue per plan task, linked from the milestone overview issue. You approve it.
4. **Build:** subagent-driven or native. Codex implements tasks where the plan already contains the code.
5. **Before the PR:** local `codex review --base main`, then a final review of the whole branch by Claude Opus.
6. **PR:** Codex reviews it automatically and the follow-up loop starts.

## 5. Going unattended

Once a PR is open, or there are eligible issues, start the loop in the session:

> /sdlc-loop

(With the plugin installed. Without it, paste the prompt from [`commands/sdlc-loop.md`](../commands/sdlc-loop.md) after `/loop`.)

**Unattended mode's guardrails:**
- It never picks `feature` issues or milestone overviews. Those need you in brainstorming.
- Design approval moves to the PR. The short design is posted on the issue and repeated in the PR, and your PR review is the approval.
- Each issue gets its own worktree under `.superpowers/issue-<N>` and a branch named `issue/<N>-<slug>`. A branch that needs code from an open PR stacks on that PR's branch.
- You're tagged, and the PR is assigned to you, whenever a loop stops. **Merging is always yours.**
- The loop only runs while the Claude Code session is open. For a durable schedule, use `/schedule`.

**When you come back:**
- Merge the PRs you're happy with.
- Answer the `needs-decision` issues.
- Run `/sdlc-resume`, or tell Claude "PRs merged". It will fix merge conflicts on the remaining stacked PRs, remove the `blocked` label from issues whose dependencies have landed, delete merged worktrees and continue.
