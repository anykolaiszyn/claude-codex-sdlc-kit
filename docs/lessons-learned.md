# Lessons learned

Every rule in the kit exists because something went wrong without it. These are the ones worth knowing before you change anything.

## Running Codex

- **`codex review --base/--uncommitted/--commit` can't take a prompt.** Passing one is an error. The review guidance lives in `AGENTS.md`, which Codex reads automatically.
- **Never read Codex's raw log.** A review log runs to thousands of lines, and reading it wastes Claude's context. `run-codex.sh` saves the log to disk and prints only the findings, or Codex's final message when the review is clean.
- **The findings marker has to match a whole line.** The log also contains the file contents Codex read. When the kit's own files were under review, a substring match on `Full review comments:` found the marker text inside them.
- **Logs are private and have unique names.** Logs can contain source code and secrets, so `run-codex.sh` sets `umask 077`. File names include the PID, so parallel runs never overwrite each other.
- **On Windows, Codex runs commands through PowerShell**, which blocks the `npx.ps1`/`npm.ps1` shims. Briefs must say `npx.cmd`/`npm.cmd`, or Codex reports that it "can't run the tests".
- **Check `codex <cmd> --help` before using a flag.** For example, `exec` has no `--ask-for-approval` flag.
- **Run reviews in the background.** Use the Bash tool's background option. A shell `&` never reports back.

## Review budget

- **A risk tier that's only an inline judgment call can't be checked.** Claude both writes the diff and decides whether it's low-risk enough to skip Codex, so the decision needs to leave a trace. Stating `Review budget: <tier> — <why>` in every PR description turns a silent, unverifiable call into something a human can spot-check on review.
- **"Universal and cost-aware" needs a real per-project knob, not just prose.** Without a bootstrap answer or an `ARCHITECTURE.md` field, "let each project tune the balance" only means "someone edits the shared docs by hand," which nobody does. `REVIEW_BUDGET` gives every install its own stated tolerance.

## Triage

- **Probe before acting.** Some Codex findings turn out to be invalid. "Fixing" them anyway adds bugs and churn. A finding's severity doesn't make it real; a probe does.
- **Blocking findings are fixed; edge cases go to the backlog.** Chasing every edge case in one PR never ends. The backlog issue records the repro, so nothing is lost.
- **A fix that is itself a fallback can collide.** For example, replacing one placeholder label with another can clash with real data too. When fixing a bug class, check the fix's own fallbacks and the sibling code.

## The PR loop

- **Match comments to a review by `pull_request_review_id`, never by the comment's `commit_id`.** GitHub moves an old comment's `commit_id` forward when its lines haven't changed, so old findings look new.
- **The Codex bot hits usage limits** and sometimes never answers. A transient error or silence shares the round's one retry on the normal 600 s cadence; after three empty checks, Claude tags you and moves on instead of spinning. A genuine quota-exhaustion response is a different failure shape — quota resets run hours to days, so it doesn't share that retry; it fails over to a Claude-equivalent review immediately instead of polling a quota that won't be back for a while. Conflating the two either wastes checks on a quota that isn't returning soon, or stalls the loop waiting on it.
- **Stop rules keep it bounded.** The loop stops on a 👍, on a round with no blocking findings, or after 3 fix rounds.
- **Tag, don't wait.** The loop @mentions you, assigns the PR to you and moves on to the next eligible issue, so a quiet reviewer never stalls the queue.

## Git hygiene

- **Only one agent commits.** When two agents both write to history, you get conflicts and commits nobody can account for.
- **Merge the base into a stacked PR; don't rebase.** Rebasing a PR that's under review loses the review's anchors. Merging keeps them.
- **Check a worktree before deleting it.** Run `git status` in every worktree before removing it. `--force` is only safe when you've confirmed that the uncommitted files are only caches.
- **Line endings.** `*.sh` files are pinned to LF in `.gitattributes`, because a CRLF shebang breaks the scripts on Windows checkouts.
