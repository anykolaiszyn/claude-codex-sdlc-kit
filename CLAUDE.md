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

## Commands

- `bash tests/bootstrap.test.sh` — smoke test: installs into a scratch repo, checks every placeholder is filled, nothing is overwritten, and a second run is a no-op.
- `bash tests/run-local-llm.test.sh` — exercises `run-local-llm.sh`'s exit-code contract (0/1/3) against a mocked local LLM endpoint, without a real one running.
- `shellcheck scripts/*.sh tests/*.sh skills/pairing-with-codex-cli/run-codex.sh skills/pairing-with-local-llms/run-local-llm.sh` — lints all shell scripts.
- `claude plugin validate .` — validates `.claude-plugin/plugin.json` and `marketplace.json`. Local-only: the `claude` CLI isn't available on CI runners, so CI validates the manifests are well-formed JSON instead (see below).
- CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs the first two test suites, the shellcheck command, and the manifest JSON check, on every push to `main` and every PR.

## Architecture

The kit ships two ways — as a Claude Code plugin (`.claude-plugin/plugin.json` + `marketplace.json`) or a manual clone — but both paths run the same installer against a target repo:

- [scripts/bootstrap.sh](scripts/bootstrap.sh): the installer. Gathers project answers (env vars, or interactive prompts), fills `{{PLACEHOLDER}}` tokens with a small inline Python substitution, copies [template/](template/) into the target repo's root (including `.claude/agents.json`, the provider config) and both `skills/pairing-with-codex-cli/` and `skills/pairing-with-local-llms/` into `.claude/skills/...`, and skips (never overwrites) any file that already exists there.
- [template/](template/): what actually lands in a consumer repo — its own `CLAUDE.md`/`AGENTS.md`, [template/docs/DEVELOPMENT-PROCESS.md](template/docs/DEVELOPMENT-PROCESS.md) (the canonical loop/roles/triage/PR-follow-up rules), `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `.claude/agents.json` (assigns each SDLC role to a provider — Codex, a Claude model, or a local LLM — and lets any be disabled), and issue templates.
- [commands/](commands): the slash commands (`/sdlc-init`, `/sdlc-loop`, `/sdlc-resume`) a consumer repo's Claude session runs; each is a thin pointer into a skill.
- [skills/setting-up-claude-codex-sdlc/](skills/setting-up-claude-codex-sdlc/SKILL.md): the install procedure `/sdlc-init` follows — preflight checks, working out bootstrap answers from the repo, running `bootstrap.sh`, probing Codex once.
- [skills/pairing-with-codex-cli/](skills/pairing-with-codex-cli/SKILL.md): how Claude drives the Codex CLI. `run-codex.sh` wraps `codex review`/`codex exec`, writes the full log to disk, and prints only findings or the exit status. Also documents finding triage (reproduce → Valid/Invalid/Unclear → blocking fix or backlog issue) and the PR follow-up loop.
- [skills/pairing-with-local-llms/](skills/pairing-with-local-llms/SKILL.md): how Claude runs a review against a local OpenAI-compatible LLM (Ollama, LM Studio, vLLM, etc.) when a role in `.claude/agents.json` is assigned to one. `run-local-llm.sh` mirrors `run-codex.sh`'s findings-only-stdout/full-log-on-disk contract, with exit 3 meaning the endpoint is unreachable so the caller falls through to the role's next configured provider.
- [scripts/labels.sh](scripts/labels.sh): creates the GitHub labels the process depends on for issue routing (`bug`, `edge-case`, `feature`, `process`, `from-codex`, `from-review`, `blocked`, `needs-decision`).

[template/docs/DEVELOPMENT-PROCESS.md](template/docs/DEVELOPMENT-PROCESS.md), [skills/pairing-with-codex-cli/SKILL.md](skills/pairing-with-codex-cli/SKILL.md), and [commands](commands) describe the same process from three angles (installed rules, Codex-pairing mechanics, command entry points) and must stay in sync — see [CONTRIBUTING.md](CONTRIBUTING.md).
