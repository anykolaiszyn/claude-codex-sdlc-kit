---
name: setting-up-claude-codex-sdlc
description: Use when installing the Claude + Codex development process into a repo — adding CLAUDE.md, AGENTS.md, docs/DEVELOPMENT-PROCESS.md, the roadmap, labels and the pairing-with-codex-cli skill — or when a repo has none of these and the user wants the Claude-orchestrates / Codex-reviews workflow.
---

# Setting up the Claude + Codex SDLC in a repo

The kit root is two directories above this skill's base directory (`<base>/../..`). It holds `scripts/bootstrap.sh`, `scripts/labels.sh` and `template/`.

## Steps

1. **Check the machine** and report anything missing. Don't install it yourself.
   - `git --version`, `gh auth status`, `codex --version` (0.156+), `codex login status`, and `python --version`.
   - **Pushing workflow files.** The requirement depends on how the repo pushes. Check with `git remote get-url origin`:
     - **HTTPS with `gh`'s stored OAuth token:** `gh auth status` should list the `workflow` scope. If it's missing, the user runs `gh auth refresh -h github.com -s workflow` **in their own terminal**; inside Claude Code the device code expires unseen.
     - **SSH remote, or a fine-grained token in `GH_TOKEN`:** the `gh` scope doesn't apply, so don't flag it. The first push that adds a workflow is the real test.
   - Ask the user to confirm the Codex GitHub configuration in `docs/github-setup.md` (kit root):
     - **Codex connected to the repo, with Code review on:** required.
     - **Automatic reviews:** recommended, not required. Without it, the PR loop requests the first review itself after two empty checks, so the first round is only slower.
   - The superpowers plugin must be installed. If its skills are missing from your skill list, tell the user to run `/plugin install superpowers@claude-plugins-official`.
2. **Work out the answers** from the repo before asking the user. Look at `package.json` scripts, `pyproject.toml`, `Makefile`, `go.mod` and the CI config.
   - Answers: `PROJECT_NAME`, `PROJECT_PITCH`, `MAIN_BRANCH`, `TEST_CMD`, `CHECK_CMD`, `CODEX_TEST_CMD`, `CODEX_CHECK_CMD`, `REVIEW_PRIORITIES`, `M1_TITLE`.
   - On Windows, the Codex commands use `.cmd` shims (`npx.cmd`, `npm.cmd`).
   - Ask only for what the repo can't tell you, typically the pitch and the review priorities. Ask one question at a time.
3. **Branch first:** `git switch -c process/claude-codex-sdlc`. Never install on the default branch.
4. **Run the bootstrap** with the answers as env vars:
   `bash "<kit>/scripts/bootstrap.sh" . --labels [--milestone "M1 — <title>"]`
   It never overwrites files. For each file it skipped, merge the kit's version into the existing one and show the user the diff.
5. `git add --chmod=+x .claude/skills/pairing-with-codex-cli/run-codex.sh`, commit, push, and open a PR titled "Adopt the Claude + Codex SDLC".
6. **Probe Codex once:** run a 15-second `run-codex.sh exec` brief that only runs `CODEX_TEST_CMD`.
   - If Codex can't run the tests, record that in `docs/DEVELOPMENT-PROCESS.md` (Roles → fallback) and use the Claude subagent fallback for implementation.
7. **Hand off:** tell the user that the next step is `superpowers:brainstorming`, to fill in `docs/ARCHITECTURE.md`. Its quality bar decides what counts as blocking. Then comes the spec, the milestone overview issues and the roadmap. After that, `/sdlc-loop` for unattended mode.
