# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Codex says it "can't run tests" on Windows | PowerShell blocks the `.ps1` shims | Use `npx.cmd`/`npm.cmd` in `AGENTS.md` and in briefs |
| `codex review` errors about a prompt | `--base/--uncommitted/--commit` take no prompt | Put the guidance in `AGENTS.md` instead |
| A local review fails with a usage-limit error | Your ChatGPT Codex quota is used up | Don't wait on the PR loop's 600 s retry — quota resets take hours to days. Fall back to a Claude Sonnet subagent review immediately, note the fallback on the PR, and try Codex again next PR or session. See `docs/DEVELOPMENT-PROCESS.md` → **Failover and quota handling** |
| The PR bot never answers `@codex review` | Code review isn't enabled for the repo, or the bot is over quota | Enable it at chatgpt.com/codex → Settings. The loop re-posts once, then tags you |
| The PR bot replies "Something went wrong" | A transient error on the bot's side | The loop re-posts once per round |
| Old findings are triaged again | Comments were matched by `commit_id` | Match by `pull_request_review_id` |
| `run-codex.sh: Permission denied` | The executable bit was lost on Windows | `git add --chmod=+x .claude/skills/pairing-with-codex-cli/run-codex.sh` |
| `bad interpreter: /usr/bin/env: bash^M` | CRLF line endings | Keep `*.sh text eol=lf` in `.gitattributes`, then run `git add --renormalize .` |
| The loop stopped when you closed the terminal | `/loop` runs inside the session | Reopen the session and run `/sdlc-resume` |
| `gh pr create --body-file /tmp/x.md` fails with `open /tmp/x.md: The system cannot find the file specified` (Git Bash on Windows) | `gh` is a native program and does not translate MSYS paths | Pass a native path: `--body-file "$(cygpath -m "$TMPDIR/x.md")"` |
| `tsc` reports `Cannot find module` right after fetching the base | The base added dependencies and `node_modules` is stale | Reinstall (`npm ci`) in the worktree, then rerun typecheck |
| One unrelated test fails in the full suite but passes alone | A timing-dependent flake under load | Rerun that file alone, then record it on the project's flaky-test `process` issue. See `docs/DEVELOPMENT-PROCESS.md` → **Flaky tests** |
| A long `npm ci` or clone times out the tool call | The foreground call has a time limit | Run it in the background and wait for its completion notice |
| The bootstrap skipped `CLAUDE.md` | The file already exists | Merge it by hand from `template/CLAUDE.md`. `/sdlc-init` does this for you |
