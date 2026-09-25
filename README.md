# Claude + Codex SDLC Kit

**Two AI agents, one disciplined process.** Claude Code orchestrates: it designs, plans, rules on findings, and makes every commit. The OpenAI Codex CLI is an independent reviewer and a low-cost implementer when the task warrants it. GitHub issues hold the backlog, and a PR follow-up loop keeps your PRs moving while you're away. Merging is always yours. The process is intentionally flexible: low-risk work stays cheap, high-risk work gets the deeper review budget, and any usage limit falls back without silently skipping the human approval gate.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)](#install)
[![Codex CLI](https://img.shields.io/badge/OpenAI-Codex%20CLI-412991)](https://github.com/openai/codex)
[![Built on superpowers](https://img.shields.io/badge/built%20on-superpowers-5319e7)](https://github.com/obra/superpowers)
[![CI](https://github.com/anykolaiszyn/claude-codex-sdlc-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/anykolaiszyn/claude-codex-sdlc-kit/actions/workflows/ci.yml)

```
 you ─ approve ─►  brainstorm ─► spec ─► plan ─► build (TDD) ─► local Codex review ─► PR
                                                  ▲                                     │
                                                  │                              @codex review
                              next eligible issue │                                     ▼
 you ◄─ tagged ──  summary + assign ◄── stop ◄── triage: probe → fix blockers / backlog edge cases
```

## Table of contents

- [Why](#why)
- [How it works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Quick start](#quick-start)
- [Commands and skills](#commands-and-skills)
- [What gets installed in your repo](#what-gets-installed-in-your-repo)
- [Unattended mode](#unattended-mode)
- [Docs](#docs)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

## Why

A single agent reviewing its own work shares its own blind spots. Two different models catch different bugs. That only helps if something keeps the pair honest:

- **Codex output is a claim, not evidence.** Every finding is reproduced with a probe before anyone acts on it, and invalid findings are answered with the evidence.
- **Blocking findings are fixed; edge cases go to the backlog.** Otherwise a PR never finishes. The line between the two is your project's written quality bar.
- **One agent owns git.** Codex never commits. Claude reviews Codex's diffs and reruns the tests itself.
- **Cheap where it can be.** Codex spends your ChatGPT quota on reviews and on implementation tasks that are fully specified. Claude spends its tokens on judgment.

The process was built and hardened on a real desktop-app project, running across dozens of PRs and review rounds. Every rule in it came from something that went wrong. See [docs/lessons-learned.md](docs/lessons-learned.md).

## How it works

| Stage | Who | Gate |
|---|---|---|
| Brainstorm → spec → plan | Claude with you ([superpowers](https://github.com/obra/superpowers) skills) | You approve each one |
| Build, test-first | Claude subagents, or Codex `exec` when the plan contains the code | Per-task review against the spec |
| Pre-PR bug hunt | `codex review --base <base>` (local) | Every finding probed |
| Final review of the whole branch | Claude (the most capable model) | One fix pass |
| PR gate | The Codex GitHub bot (`@codex review`) | PR follow-up loop |
| Merge | **You** | — |

The full rules are in [`template/docs/DEVELOPMENT-PROCESS.md`](template/docs/DEVELOPMENT-PROCESS.md). The kit installs that file into your repo, so both agents read it in every session.

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

Each installed repo states its own tolerance in `docs/ARCHITECTURE.md` → **Review budget** (the `REVIEW_BUDGET` answer at install time), and every PR names the tier it used (`Review budget: <tier> — <why>`) so the call is visible, not just an inline judgment nobody can check. The canonical risk-tier table and the failover rules live in **[template/docs/DEVELOPMENT-PROCESS.md](template/docs/DEVELOPMENT-PROCESS.md)**; **[docs/customizing.md](docs/customizing.md)** covers tuning it per project.

### GitHub and Codex configuration

Before the first install, configure the repo and connect Codex. The full walkthrough is in **[docs/github-setup.md](docs/github-setup.md)**:
1. **Repo:** Issues on, and head branches deleted automatically.
2. **Default branch protected, including against you:** PR required, 0 approvals when you work alone, force pushes blocked, and no admin bypass. Claude pushes as you, the repo's admin. This is free on public repos; private repos need GitHub Pro or higher.
3. **Pushing workflow files:** with HTTPS through `gh`, add the `workflow` scope. SSH keys and fine-grained tokens are covered in the guide.
4. **Codex connected to GitHub:** at [chatgpt.com/codex](https://chatgpt.com/codex), connect GitHub (this installs the ChatGPT Codex Connector app) and grant it the repo. Create an environment for the repo, then under **Settings → Code review** turn on **Code review** (required) and **Automatic reviews** (recommended). Without Code review, PRs get no Codex review, and the loop can only tag you.
5. **Notifications:** GitHub doesn't notify you about your own activity, and Claude acts as you. Claude Code's push notification is your alert, and `assignee:@me` lists the waiting PRs.

## Install

**As a Claude Code plugin (recommended):**

```text
/plugin marketplace add anykolaiszyn/claude-codex-sdlc-kit
/plugin install claude-codex-sdlc@claude-codex-sdlc-kit
```

**Or manually, without the plugin:**

```bash
git clone https://github.com/anykolaiszyn/claude-codex-sdlc-kit
claude-codex-sdlc-kit/scripts/bootstrap.sh path/to/your-repo --labels
```

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
| Skill | `setting-up-claude-codex-sdlc` | The install procedure `/sdlc-init` follows |

## What gets installed in your repo

| File | Read by | Purpose |
|---|---|---|
| `CLAUDE.md` | Claude | Non-negotiables, and a pointer to the process |
| `AGENTS.md` | Codex | Its roles, the implementer rules, and review guidelines (every finding marked blocking or edge case) |
| `docs/DEVELOPMENT-PROCESS.md` | both | Loop, roles, triage, PR loop, issues, unattended mode, session start |
| `docs/ARCHITECTURE.md` | both | Brief, stack, milestones, the **quality bar**, and the **review budget** (filled in during brainstorming) |
| `docs/ROADMAP.md` | both | A readable view of the milestones (issues are the source of truth) |
| `.claude/skills/pairing-with-codex-cli/` | Claude | A repo copy of the skill, so teammates without the plugin get it too |
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

## Docs

- [GitHub setup](docs/github-setup.md): the repo, branch protection, `gh` permissions, connecting Codex and notifications
- [Manual setup guide](docs/setup-guide.md): step-by-step setup without the plugin
- [Customising](docs/customizing.md): the quality bar, timings, roles, and stacks other than Node
- [Lessons learned](docs/lessons-learned.md): why each rule exists
- [Troubleshooting](docs/troubleshooting.md): Codex quota, Windows shims, missing reviews

## FAQ

**Do I need both subscriptions?** Yes, as designed: at least Claude Pro and ChatGPT Plus. Without Codex, the Roles table's fallbacks (Claude subagents) can do the reviews and implementation, but you lose the independent second model, which is the point of the kit. See [docs/customizing.md](docs/customizing.md#roles).

**Does it work outside Node/TypeScript?** Yes. Only four commands are specific to a stack: test, check, and the two Codex runs. See [docs/customizing.md](docs/customizing.md).

**Will it merge or push to `main`?** No. It never commits on the default branch, and merging is always yours.

**Can Codex push?** No. `AGENTS.md` forbids it, and Claude reviews every Codex diff before committing it.

## Contributing

Issues and PRs are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). The kit is developed with its own process.

## License

[MIT](LICENSE)
