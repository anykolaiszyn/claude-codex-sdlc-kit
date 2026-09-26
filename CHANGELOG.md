# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- The README's Prerequisites section: minimum paid plans (Claude Pro, ChatGPT Plus) with links, a tools table including the superpowers plugin from Anthropic's official marketplace, and a summary of the GitHub and Codex configuration.
- `docs/github-setup.md`: repo settings, branch protection, `gh` permissions, connecting Codex and turning on automatic code review, and notifications.
- `.claude/agents.json`: assigns each SDLC role (implementation, task review, pre-PR review, final review, PR gate) to a provider — Codex, a Claude subagent model, or a local OpenAI-compatible LLM — and lets any provider be disabled without breaking the process's failover rules.
- `pairing-with-local-llms` skill and `run-local-llm.sh`: runs a review against a local LLM endpoint (Ollama, LM Studio, vLLM, etc.) with the same log-to-disk/findings-only contract as `run-codex.sh`.

### Changed
- Plugin renamed to `agent-sdlc` (marketplace `agent-sdlc-kit`) to reflect pluggable, multi-provider support; the GitHub repo path is unchanged.

### Fixed (Codex review of #2)
- Automatic reviews is recommended, not required: the loop recovers a missing first review.
- Workflow-file push permission now depends on the push method: HTTPS through `gh`, SSH, or a fine-grained token.
- Branch protection on private repos needs GitHub Pro or higher.
- Branch protection must not exempt admins: use a ruleset with an empty bypass list, or "Do not allow bypassing the above settings" on a classic rule.
- Self-mentions don't notify on GitHub: Claude Code's push notification is the alert, and `assignee:@me` is the queue.

### Fixed
- ShellCheck SC2163 in `bootstrap.sh` (intentional indirect export).
- CI: `actions/checkout@v7` (Node 24); runner pinned to `ubuntu-24.04`.

## [0.1.0] — 2026-09-23

### Added
- Claude Code plugin and marketplace manifests.
- Commands: `/sdlc-init`, `/sdlc-loop` and `/sdlc-resume`.
- Skills:
  - `pairing-with-codex-cli`: running Codex, triage, delegation, and the PR follow-up loop
  - `setting-up-claude-codex-sdlc`: the install procedure
- `scripts/bootstrap.sh`, which installs the process into a repo without overwriting its files, and `scripts/labels.sh`.
- Templates:
  - `CLAUDE.md` and `AGENTS.md`
  - `docs/DEVELOPMENT-PROCESS.md`, `docs/ARCHITECTURE.md` and `docs/ROADMAP.md`
  - issue templates
- `run-codex.sh` writes owner-only logs, and adds the PID to each log name so runs never collide.
- Docs: the setup guide, customising, lessons learned and troubleshooting.
- CI: ShellCheck, manifest checks and the bootstrap smoke test.
