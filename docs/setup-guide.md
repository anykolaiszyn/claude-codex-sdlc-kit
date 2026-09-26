# Setup guide and technical reference

This is the full technical reference for the kit: prerequisites, install paths, what gets installed, unattended mode, and a manual (no-plugin) walkthrough. If you just want to understand what the kit is and why it exists, see the [README](../README.md) instead.

## Table of contents

- [Prerequisites](#prerequisites)
- [Install](#install)
- [Quick start](#quick-start)
- [Commands and skills](#commands-and-skills)
- [What gets installed in your repo](#what-gets-installed-in-your-repo)
- [Unattended mode](#unattended-mode)
- [FAQ](#faq)
- [Manual walkthrough (no plugin)](#manual-walkthrough-no-plugin)

## Prerequisites

### Paid subscriptions (both are required)

| Service | Minimum plan | Why | Details |
|---|---|---|---|
| **Claude** | **Pro, $20/month.** Max (from $100/month) is recommended for unattended runs. | Claude Code is the orchestrator. The free claude.ai plan doesn't include Claude Code. Team, Enterprise and an API Console account also work. | [claude.com/pricing](https://claude.com/pricing) · [Claude Code setup](https://code.claude.com/docs/en/setup) |
| **ChatGPT (Codex)** | **Plus, $20/month.** Pro is recommended for heavy review volume. | The Codex CLI and Codex's automatic GitHub code review. The free plan doesn't include either. | [Codex pricing](https://learn.chatgpt.com/docs/pricing) · [Codex on GitHub](https://learn.chatgpt.com/docs/third-party/github) |

Both plans have usage limits, and unattended mode uses a lot of them: every PR costs a local Codex review, one or more PR-bot reviews, and Claude's triage. On the entry plans, expect to hit limits during long sessions. The kit handles this: it retries once, then tags you and moves on. Prices were checked in September 2026; follow the links for current figures.

### Tools

| Tool | Install | Check |
|---|---|---|
| [Claude Code](https://code.claude.com/docs/en/setup) | `irm https://claude.ai/install.ps1 \| iex` (Windows) or `curl -fsSL https://claude.ai/install.sh \| bash` | `claude --version` |
| [superpowers](https://github.com/obra/superpowers) plugin, from Anthropic's official marketplace | In Claude Code: `/plugin install superpowers@claude-plugins-official` (if the marketplace is missing: `/plugin marketplace add anthropics/claude-plugins-official`) | `/plugin` lists `superpowers` |
| [Codex CLI](https://github.com/openai/codex) 0.156 or later | `npm i -g @openai/codex`, then `codex login` with your ChatGPT account | `codex --version` |
| [GitHub CLI](https://cli.github.com) | Install, then `gh auth login` (and `gh auth refresh -s workflow` if you push over HTTPS with it) | `gh auth status` shows you're logged in |
| Git (Git Bash on Windows) and Python 3 | [git-scm.com](https://git-scm.com/downloads), [python.org](https://www.python.org/downloads/) | `git --version`, `python --version` |

The kit depends on superpowers for brainstorming, specs, plans, TDD and subagent-driven builds. Install superpowers first.

### Flexible agent policy

The kit is designed to be universal and cost-aware. In practice, that means:
- start with the cheapest viable model or review path
- escalate only when the change is risky, ambiguous, or cross-cutting
- keep Codex for high-value reviews rather than blanket use
- let each project tune the balance between speed, safety, and quota cost

Each installed repo states its own tolerance in `docs/ARCHITECTURE.md` → **Review budget** (the `REVIEW_BUDGET` answer at install time), and every PR names the tier it used (`Review budget: <tier> — <why>`) so the call is visible, not just an inline judgment nobody can check. The canonical risk-tier table and the failover rules live in **[template/docs/DEVELOPMENT-PROCESS.md](../template/docs/DEVELOPMENT-PROCESS.md)**; **[customizing.md](customizing.md)** covers tuning it per project.

Every role — implementation, review, or the PR gate — can also be reassigned to a different model (a local one too, for review roles) or turned off if you're using that quota elsewhere. See **[customizing.md](customizing.md#roles-and-providers)**.

### GitHub and Codex configuration

Before the first install, configure the repo and connect Codex. The full walkthrough is in **[github-setup.md](github-setup.md)**:
1. **Repo:** Issues on, and head branches deleted automatically.
2. **Default branch protected, including against you:** PR required, 0 approvals when you work alone, force pushes blocked, and no admin bypass. Claude pushes as you, the repo's admin. This is free on public repos; private repos need GitHub Pro or higher.
3. **Pushing workflow files:** with HTTPS through `gh`, add the `workflow` scope. SSH keys and fine-grained tokens are covered in the guide.
4. **Codex connected to GitHub:** at [chatgpt.com/codex](https://chatgpt.com/codex), connect GitHub (this installs the ChatGPT Codex Connector app) and grant it the repo. Create an environment for the repo, then under **Settings → Code review** turn on **Code review** (required) and **Automatic reviews** (recommended). Without Code review, PRs get no Codex review, and the loop can only tag you.
5. **Notifications:** GitHub doesn't notify you about your own activity, and Claude acts as you. Claude Code's push notification is your alert, and `assignee:@me` lists the waiting PRs.

## Install

**As a Claude Code plugin (recommended):**

```text
/plugin marketplace add anykolaiszyn/claude-codex-sdlc-kit
/plugin install agent-sdlc@agent-sdlc-kit
```

**Or manually, without the plugin:** see [Manual walkthrough](#manual-walkthrough-no-plugin) below.

## Quick start

Open Claude Code in your repo:

```text
/sdlc-init First usable slice
```

Claude checks your machine, works out your test and check commands, and creates a branch. It then installs the process files and labels, probes Codex once, and opens a PR. Next:

```text
Let's brainstorm the project.
```

Brainstorming fills in `docs/ARCHITECTURE.md`, including the **quality bar**, which decides what counts as blocking. It's followed by the spec, the milestone issues and the plan. Once the first PR is up:

```text
/sdlc-loop
```

When you come back and have merged the PRs you're happy with:

```text
/sdlc-resume
```

## Commands and skills

| | Name | What it does |
|---|---|---|
| Command | `/sdlc-init [milestone]` | Installs the process into the current repo |
| Command | `/sdlc-loop [PRs]` | Starts the unattended PR follow-up loop and issue pickup |
| Command | `/sdlc-resume` | After merges: fixes conflicts on the remaining PRs, unblocks issues, removes merged worktrees, continues |
| Skill | `pairing-with-codex-cli` | How to run Codex (`run-codex.sh` keeps its long logs out of Claude's context), how to triage findings, how to delegate tasks, and the PR loop |
| Skill | `pairing-with-local-llms` | How to run a review against a local OpenAI-compatible LLM (`run-local-llm.sh`) when a role is assigned to one |
| Skill | `setting-up-claude-codex-sdlc` | The install procedure `/sdlc-init` follows |

## What gets installed in your repo

| File | Read by | Purpose |
|---|---|---|
| `CLAUDE.md` | Claude | Non-negotiables, and a pointer to the process |
| `AGENTS.md` | Codex | Its roles, the implementer rules, and review guidelines (every finding marked blocking or edge case) |
| `docs/DEVELOPMENT-PROCESS.md` | both | Loop, roles, triage, PR loop, issues, unattended mode, session start |
| `docs/ARCHITECTURE.md` | both | Brief, stack, milestones, the **quality bar**, and the **review budget** (filled in during brainstorming) |
| `docs/ROADMAP.md` | both | A readable view of the milestones (issues are the source of truth) |
| `.claude/agents.json` | Claude | Assigns each SDLC role to a provider (Codex, a Claude model, or a local LLM) and lets you disable any of them |
| `.claude/skills/pairing-with-codex-cli/` | Claude | A repo copy of the skill, so teammates without the plugin get it too |
| `.claude/skills/pairing-with-local-llms/` | Claude | A repo copy of the local-LLM review adapter, for teammates without the plugin |
| `.github/ISSUE_TEMPLATE/` | you and Claude | Backlog-finding and milestone-overview templates |
| Labels | GitHub | Type: `bug`, `edge-case`, `feature`, `process`. Source: `from-codex`, `from-review`. Status: `blocked`, `needs-decision`. |

The bootstrap **never overwrites** existing files. It lists the ones it skipped so they can be merged by hand.

## Unattended mode

When a PR's loop stops, Claude tags you, assigns the PR to you, and picks up the next eligible issue:
- Eligible issues are labelled `bug`, `edge-case` or `process`, aren't labelled `blocked` or `needs-decision`, and have no open `Depends on #N`.
- It **never** picks up `feature` issues or milestone overviews. Those need you in brainstorming.
- Design approval moves to the PR. The design is posted on the issue, and your review is the approval.
- Each issue gets its own worktree and an `issue/<N>-<slug>` branch. A branch that needs code from an open PR is stacked on that PR's branch.
- When nothing is left to pick up, it stops, sends you a push notification, and lists what's waiting for you.

The loop runs inside your Claude Code session. Closing the session stops it.

## FAQ

**Do I need both subscriptions?** Yes, as designed: at least Claude Pro and ChatGPT Plus. Without Codex, the Roles table's fallbacks (Claude subagents) can do the reviews and implementation, but you lose the independent second model, which is the point of the kit. See [customizing.md](customizing.md#roles-and-providers).

**Does it work outside Node/TypeScript?** Yes. Only four commands are specific to a stack: test, check, and the two Codex runs. See [customizing.md](customizing.md).

**Will it merge or push to `main`?** No. It never commits on the default branch, and merging is always yours.

**Can Codex push?** No. `AGENTS.md` forbids it, and Claude reviews every Codex diff before committing it.

## Manual walkthrough (no plugin)

This walkthrough sets the kit up without the plugin, or explains what `/sdlc-init` does for you.

### 1. One-time machine setup

You need the paid plans and tools listed in [Prerequisites](#prerequisites) above, and the repo configured as described in [GitHub setup](github-setup.md).

If you don't use the plugin, you can still make the skill available to every project, not just repos that have the kit installed:
```bash
cp -r skills/pairing-with-codex-cli ~/.claude/skills/
```
The in-repo copy wins when both exist.

### 2. Install into a project

```bash
git clone https://github.com/anykolaiszyn/claude-codex-sdlc-kit && cd claude-codex-sdlc-kit
scripts/bootstrap.sh ../MyProject --labels --milestone "M1 — First usable slice"
```

The script asks for the project name, a pitch, the default branch, and the test and check commands. It asks separately for the commands Codex runs; on Windows they must use `npx.cmd`/`npm.cmd`. It also asks for the review priorities, and for a local LLM endpoint if you have one (leave it blank to skip). To skip the prompts, set these environment variables:

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

### 3. Check Codex once per machine and repo

```bash
cd ../MyProject
S=.claude/skills/pairing-with-codex-cli
echo "Run the test command ($CODEX_TEST_CMD) and report the summary line. Do not edit files." > /tmp/probe.md
"$S/run-codex.sh" exec /tmp/probe.md -C .
```
If Codex can't run the tests, skip Codex implementation in this repo. The roles table's fallback covers it: a Claude Haiku or Sonnet subagent does the work instead. Reviews still work.

### 4. First session: brainstorm

Open Claude Code in the repo and paste:

> Read CLAUDE.md and docs/DEVELOPMENT-PROCESS.md. We're starting this project from scratch. Use superpowers:brainstorming to shape the brief in docs/ARCHITECTURE.md (users, fixed stack, non-goals, milestones, and the quality bar that defines "blocking"). Then write the spec, and once I approve it, create a milestone overview issue for each milestone and update docs/ROADMAP.md. Stop at each approval gate.

Here's what happens:
1. **Brainstorming:** one question at a time. You approve the design.
2. **Spec** in `docs/superpowers/specs/`. You approve it.
3. **Plan** in `docs/superpowers/plans/`. One task issue per plan task, linked from the milestone overview issue. You approve it.
4. **Build:** subagent-driven or native. Codex implements tasks where the plan already contains the code.
5. **Before the PR:** local `codex review --base main`, then a final review of the whole branch by Claude Opus.
6. **PR:** Codex reviews it automatically and the follow-up loop starts.

### 5. Going unattended

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
