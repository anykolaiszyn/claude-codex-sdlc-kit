# claude-codex-sdlc-kit — instructions for Claude

This repo is the kit itself: a Claude Code plugin with `.claude-plugin/`, `commands/`, and `skills/`, plus `template/` and `scripts/` that install the process into other repositories. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Operating rules

- Never commit on `main`. Work on a branch and open a PR.
- Keep the process rules aligned across [template/docs/DEVELOPMENT-PROCESS.md](template/docs/DEVELOPMENT-PROCESS.md), [skills/pairing-with-codex-cli/SKILL.md](skills/pairing-with-codex-cli/SKILL.md), and [commands](commands).
- Template files use `{{PLACEHOLDERS}}`. When adding a new one, update both [scripts/bootstrap.sh](scripts/bootstrap.sh) and [tests/bootstrap.test.sh](tests/bootstrap.test.sh).
- Prefer linking to existing documentation instead of duplicating it in agent instructions.
- Verify with `bash tests/bootstrap.test.sh` and `claude plugin validate .` after relevant changes.
- Nothing in the kit may name a specific private project, path, or person.

## Repo-specific guardrails

- The bootstrap must never overwrite existing files; it should skip and report those it cannot safely install.
- Shell code should be portable across Git Bash, macOS, and Linux: quote paths carefully and avoid fragile assumptions.
- When changing workflow or install behavior, validate the real bootstrap contract in [tests/bootstrap.test.sh](tests/bootstrap.test.sh) before finalizing the patch.
