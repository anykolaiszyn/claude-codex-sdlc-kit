# claude-codex-sdlc-kit — instructions for Claude

This repo *is* the kit: a Claude Code plugin with `.claude-plugin/`, `commands/` and `skills/`, plus `template/` and `scripts/`, which install the process into other repos. See `CONTRIBUTING.md`.

- Never commit on `main`. Work on a branch and open a PR.
- The process rules live in three places that must agree: `template/docs/DEVELOPMENT-PROCESS.md`, `skills/pairing-with-codex-cli/SKILL.md` and `commands/*.md`.
- `template/` files use `{{PLACEHOLDERS}}`. Add each new placeholder to `scripts/bootstrap.sh` (the `ask` lines) and to `tests/bootstrap.test.sh`.
- Verify with `bash tests/bootstrap.test.sh` and `claude plugin validate .`.
- Nothing in the kit may name a specific private project, path or person.
