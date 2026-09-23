# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
