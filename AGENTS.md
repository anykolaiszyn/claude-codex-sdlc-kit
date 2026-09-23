# claude-codex-sdlc-kit — instructions for Codex

This repo is a Claude Code plugin and a set of templates that install a Claude + Codex development process into other repos.

## Review guidelines

- Prioritise:
  - Shell correctness in `scripts/` and `run-codex.sh`: quoting, paths with spaces, `set -euo pipefail` pitfalls, and portability between Git Bash, macOS and Linux
  - the bootstrap's promise never to overwrite user files
  - contradictions between `template/docs/DEVELOPMENT-PROCESS.md`, `skills/pairing-with-codex-cli/SKILL.md` and `commands/*.md`
- Mark each finding **blocking** or **edge case**, and give a concrete failing input.
- Skip wording nits.
