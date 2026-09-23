---
description: Resume after you've merged PRs — fix conflicts on the rest, unblock issues, clean worktrees, continue
---

Follow "Starting a session" in `docs/DEVELOPMENT-PROCESS.md`, then:
1. `git fetch --prune`. List the merged PRs and the ones still open.
2. For each open PR that now conflicts, merge its base into it. **Don't rebase or force-push.** Resolve the conflict so that both sides' intent is kept, run the tests and the check command, push, and comment on the PR.
3. Remove the `blocked` label from each issue whose "Depends on #N" issues are all closed, and comment on the issue.
4. Remove the worktrees under `.superpowers/` whose branches are merged. First check each one with `git status`, and report anything uncommitted instead of deleting it.
5. Report the state: which PRs are awaiting review, which `needs-decision` issues are waiting, and which issues are now eligible. Then continue in unattended mode (`/sdlc-loop`), unless a milestone needs brainstorming with the user.
