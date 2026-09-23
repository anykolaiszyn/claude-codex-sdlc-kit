# Claude + Codex SDLC Kit

**Two AI agents, one disciplined process.** Claude Code orchestrates: it designs, plans, rules on findings, and makes every commit. The OpenAI Codex CLI is an independent reviewer and a low-cost implementer. GitHub issues hold the backlog, and a PR follow-up loop keeps your PRs moving while you're away. Merging is always yours.

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

## Install

**Prerequisites:**
- [Claude Code](https://claude.com/claude-code)
- the [superpowers](https://github.com/obra/superpowers) plugin
- the [Codex CLI](https://github.com/openai/codex) (0.156 or later), logged in with a ChatGPT plan
- the [GitHub CLI](https://cli.github.com), authenticated
- Git Bash on Windows, and Python 3

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

**For PR reviews,** turn on Codex's GitHub code review for your repo at chatgpt.com/codex → Settings.

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
| `docs/ARCHITECTURE.md` | both | Brief, stack, milestones and the **quality bar** (filled in during brainstorming) |
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

- [Manual setup guide](docs/setup-guide.md): step-by-step setup without the plugin
- [Customising](docs/customizing.md): the quality bar, timings, roles, and stacks other than Node
- [Lessons learned](docs/lessons-learned.md): why each rule exists
- [Troubleshooting](docs/troubleshooting.md): Codex quota, Windows shims, missing reviews

## FAQ

**Do I need both subscriptions?** Codex reviews are the point of the kit. Without Codex, the Roles table's fallbacks (Claude Haiku or Sonnet subagents) can take over implementation, but you lose the independent reviewer.

**Does it work outside Node/TypeScript?** Yes. Only four commands are specific to a stack: test, check, and the two Codex runs. See [docs/customizing.md](docs/customizing.md).

**Will it merge or push to `main`?** No. It never commits on the default branch, and merging is always yours.

**Can Codex push?** No. `AGENTS.md` forbids it, and Claude reviews every Codex diff before committing it.

## Contributing

Issues and PRs are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). The kit is developed with its own process.

## License

[MIT](LICENSE)
