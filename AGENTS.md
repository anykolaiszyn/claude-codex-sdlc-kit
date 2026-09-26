# claude-codex-sdlc-kit — instructions for Codex

This repo is the Claude Code plugin and the bootstrap templates that install a disciplined Claude + Codex workflow into other repositories.

## Start here

- Read [docs/setup-guide.md](docs/setup-guide.md) for the high-level workflow, commands, and install path.
- Read [template/docs/DEVELOPMENT-PROCESS.md](template/docs/DEVELOPMENT-PROCESS.md) for the source-of-truth workflow and review loop.
- Read [skills/pairing-with-codex-cli/SKILL.md](skills/pairing-with-codex-cli/SKILL.md) for the Codex review and triage workflow.
- Read [tests/bootstrap.test.sh](tests/bootstrap.test.sh) before changing bootstrap behavior; it defines the expected install contract.

## Repo conventions

- Keep the process rules in sync across [template/docs/DEVELOPMENT-PROCESS.md](template/docs/DEVELOPMENT-PROCESS.md), [skills/pairing-with-codex-cli/SKILL.md](skills/pairing-with-codex-cli/SKILL.md), and [commands](commands).
- When adding or changing template placeholders, update both [scripts/bootstrap.sh](scripts/bootstrap.sh) and [tests/bootstrap.test.sh](tests/bootstrap.test.sh).
- The bootstrap must never overwrite existing user files; it should skip and report files it cannot safely install.
- Shell scripts must be portable and robust: quote paths, handle Windows/Git Bash paths, and prefer `set -euo pipefail` patterns.
- Prefer linking to existing documentation instead of duplicating it in new instructions.

## Working rules for Codex

- Treat findings as evidence-backed claims: reproduce the issue with a concrete probe before acting.
- Mark every review finding as either **blocking** or **edge case**, with a specific failing input or reproduction path.
- Do not commit directly to `main`; use a branch and a PR flow for changes.
- Do not overwrite user-owned files or silently change downstream project behavior while working on the kit itself.
- Skip wording-only nits unless a rule is genuinely wrong or the behavior is unsafe.

## Validation

- Run `bash tests/bootstrap.test.sh` after bootstrap-related changes.
- If available, also run `claude plugin validate .` before finishing changes to repo-level instructions or plugin metadata.
