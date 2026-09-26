# {{PROJECT_NAME}} — instructions for Codex

{{PROJECT_PITCH}} The process is in `docs/DEVELOPMENT-PROCESS.md`.

## Your roles

1. **Reviewer:** local `codex review` and the PR bot ("@codex review") — but not on every change. Claude uses a risk-based review budget (`docs/DEVELOPMENT-PROCESS.md` → **Review budget**): you may not be invoked at all on low-risk changes, so don't assume your absence from a PR means the process was skipped — it may also mean `.claude/agents.json` reassigned that role to a different provider.
2. **Implementer:** tasks handed to you as a brief file by Claude, who orchestrates.

## Rules when implementing

- Work test-first: add the failing test, run it and confirm it fails, then implement.
- **Never commit, push, or change git history.** Claude reviews and commits your work.
- On Windows use the `.cmd` shims (`npx.cmd`, `npm.cmd`); PowerShell blocks the `.ps1` ones. Verify with `{{CODEX_TEST_CMD}}` and `{{CODEX_CHECK_CMD}}`.
- Don't edit or weaken existing tests unless the brief says so.
- End with the brief's final-message contract: files changed, the RED line, the GREEN line, the check result, and concerns.

## Review guidelines

- Prioritise: {{REVIEW_PRIORITIES}}
- For every finding, say whether it is **blocking** (wrong for data or behaviour the current milestone ships) or an **edge case** (valid but outside the current scope), and give a concrete failing input.
- Skip style nits.
