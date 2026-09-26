# GitHub setup (before you install the kit)

Do this once per repo, before `/sdlc-init`. It takes about 10 minutes.

## 1. The repository

- **Create the repo** on GitHub, and clone it locally or add the remote. The kit works on new and existing repos.
- **Settings → General → Features:** make sure **Issues** is on. The backlog, milestone overviews and unattended mode all run on issues.
- **Settings → General → Pull Requests:**
  - Turn on **Automatically delete head branches**. The kit creates one branch per issue.
  - Merge strategy: any. The kit merges the base into a stacked PR instead of rebasing, so review threads keep their anchors.
- **Settings → Actions → General:** allow Actions if you want CI.

## 2. Protect the default branch

Claude pushes with *your* GitHub account, so protect `main` against accidents.

> **Plan note:** branch protection and rulesets work on **public** repos on every GitHub plan. For **private** repos they need GitHub **Pro, Team or Enterprise** ([GitHub docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)). On a private repo with GitHub Free, skip this step. The kit's own rule, never commit on the default branch, still applies; nothing on GitHub enforces it.

**Make the rule apply to you too.** You own the repo, so you're its administrator, and Claude pushes as you. A rule that admins can bypass protects nothing here.

- **Recommended:** go to **Settings → Rules → Rulesets → New branch ruleset**, target the default branch, and set **Enforcement status: Active**. **Leave the Bypass list empty.** Rulesets exempt no one unless you add them, so the rule applies to your account.
- **Classic alternative:** go to **Settings → Branches → Add branch protection rule** and turn on **Do not allow bypassing the above settings**. By default, classic rules [don't apply to admins](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), so without this option a direct `git push origin main` still succeeds.

Either way, turn on:
  - **Require a pull request before merging:** on.
  - **Required approvals: 0 when you work alone.** GitHub doesn't let you approve your own PR, and Claude's PRs are opened as you. Merging is the approval. Teams can require 1.
  - **Require status checks to pass:** add your CI job once it has run at least once.
  - **Block force pushes:** on.

## 3. The GitHub CLI and its permissions

```bash
gh auth login                                   # log in through the browser
gh auth status                                  # Claude uses gh for issues, PRs and comments
```

**Pushing workflow files** (`.github/workflows/*`) needs extra permission. Which one depends on how you push. Run `git remote get-url origin` to see:
- **HTTPS using `gh`'s stored login:** run `gh auth refresh -h github.com -s workflow`. `gh auth status` should then list `workflow` among the token scopes.
- **SSH (`git@github.com:…`):** pushes use your SSH key. The `gh` scope doesn't matter.
- **A fine-grained personal access token** (for example in `GH_TOKEN`): give it **Workflows: Read and write** on the repo.

Run `gh auth refresh` **in your own terminal**, not through Claude Code's `!` prefix. It shows a one-time code to enter at https://github.com/login/device, and inside Claude Code that code scrolls out of sight and expires. Without that permission, any push that adds or changes a workflow file is rejected with `refusing to allow an OAuth App to create or update workflow`.

Also set your git identity, which is used for every commit Claude makes:
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

## 4. Connect Codex to GitHub (the PR reviewer)

This needs a paid ChatGPT plan (Plus or higher; see [Prerequisites](setup-guide.md#prerequisites)).

1. Go to **https://chatgpt.com/codex** and sign in with the same ChatGPT account the Codex CLI uses.
2. **Connect GitHub** when prompted. This installs the **ChatGPT Codex Connector** GitHub app.
   - Under *Repository access*, choose the repos Codex may see: *Only select repositories* is safest.
   - To add a repo later: **GitHub → Settings → Applications → ChatGPT Codex Connector → Configure**.
3. **Create an environment for the repo** at https://chatgpt.com/codex/settings/environments. The defaults are fine for review. Add setup commands only if you also want Codex cloud to run your tests.
4. **Turn on code review:** open Codex settings → **Code review**, then:
   - turn on **Code review** for the repo. This is **required**.
   - turn on **Automatic reviews**. This is **recommended**: every new PR is reviewed without a comment. Without it, the PR loop requests the first review itself after two empty checks, about 20 minutes later. Later rounds always use `@codex review`.
5. **Test it:** open a small PR and wait. Codex reacts with 👀, then posts a review, or a 👍 reaction when it finds nothing. Commenting `@codex review` should do the same.

Official docs: [Use Codex with GitHub](https://learn.chatgpt.com/docs/third-party/github) and [Codex cloud](https://learn.chatgpt.com/docs/cloud).

**How Codex reads your rules:** Codex reads `AGENTS.md` at the repo root, both locally and for PR reviews. The kit's template puts its review rules there, including the requirement to mark every finding blocking or edge case, so you don't configure anything else.

## 5. Notifications

When a PR's loop stops, Claude posts a summary that `@mention`s you and assigns the PR to you. **GitHub doesn't notify you about your own activity,** though. Claude acts through *your* account, so on a solo setup that mention and assignment **won't** produce a GitHub notification. They're markers, not alerts:
- **The alert is Claude Code's push notification.** The loop sends one when it stops. Make sure notifications are enabled wherever you run Claude Code (`/config`), or that you have the mobile app connected.
- **To find the PRs waiting for you,** use the filter `is:open is:pr assignee:@me`, or GitHub → Pull requests → **Assigned**.
- **To get real GitHub notifications,** Claude has to post as a different identity, such as a bot account or a GitHub App token given to `gh`. Teams get this for free: when you're not the account Claude uses, your mentions notify you normally.

## 6. Labels and milestones

`/sdlc-init` creates these for you. By hand:
```bash
scripts/labels.sh path/to/repo
gh api repos/OWNER/REPO/milestones -f title="M1 — First usable slice"
```

## Checklist

- [ ] Issues are on, and head branches are deleted automatically
- [ ] Default branch protected: PR required, 0 approvals when solo, force pushes blocked, **no bypass for admins** (a ruleset with an empty bypass list, or "Do not allow bypassing"). Needs a public repo, or GitHub Pro or higher for a private one.
- [ ] `gh` is logged in, and your push method can write workflow files
- [ ] Git `user.name` and `user.email` are set
- [ ] ChatGPT Codex Connector has access to the repo
- [ ] Codex environment created; **Code review** on (and **Automatic reviews**, recommended)
- [ ] A test PR got a Codex review or a 👍
- [ ] Claude Code push notifications reach you (or you check `assignee:@me`)
