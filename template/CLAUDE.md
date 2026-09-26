# {{PROJECT_NAME}} — instructions for Claude

{{PROJECT_PITCH}} The product brief and milestones are in `docs/ARCHITECTURE.md`.

**Follow `docs/DEVELOPMENT-PROCESS.md`.** It covers the loop, roles, triage, the PR follow-up loop, issues, and how to start a session.

Non-negotiables:
- You orchestrate and are the only agent that commits or pushes. Never commit on `{{MAIN_BRANCH}}`.
- Use the superpowers skills (brainstorming → spec → plan → subagent-driven build), and `pairing-with-codex-cli` whenever Codex reviews or implements.
- Roles have a default agent, but `.claude/agents.json` can reassign or disable any of them (including local LLMs) — check it before assuming Codex.
- Probe every reviewer finding before acting. Blocking findings get fixed in the PR; edge cases get backlog issues.
- Tests: `{{TEST_CMD}}`, `{{CHECK_CMD}}`. Codex on Windows needs the `.cmd` shims (`npx.cmd`, `npm.cmd`).
- Stay inside the current milestone's scope (`docs/ROADMAP.md`); anything else becomes an issue.
- When a PR loop stops, tag the user and continue with the next eligible issue (`docs/DEVELOPMENT-PROCESS.md#unattended-mode`); never stop to ask.
