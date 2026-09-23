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

Claude pushes with *your* GitHub account, so protect `main` against accidents:

- **Settings → Rules → Rulesets → New branch ruleset** (or **Branches → Add branch protection rule**), targeting the default branch:
  - **Require a pull request before merging:** on.
  - **Required approvals: 0 when you work alone.** GitHub doesn't let you approve your own PR, and Claude's PRs are opened as you. Merging is the approval. Teams can require 1.
  - **Require status checks to pass:** add your CI job once it has run at least once.
  - **Block force pushes:** on.

## 3. The GitHub CLI and its permissions

```bash
gh auth login                                   # HTTPS, log in through the browser
gh auth refresh -h github.com -s workflow       # needed to push .github/workflows/*
gh auth status                                  # Token scopes should include: repo, workflow, read:org
```

Run `gh auth refresh` **in your own terminal**, not through Claude Code's `!` prefix. It shows a one-time code to enter at https://github.com/login/device, and inside Claude Code that code scrolls out of sight and expires. Without the `workflow` scope, any push that adds or changes a workflow file is rejected with `refusing to allow an OAuth App to create or update workflow`.

Also set your git identity, which is used for every commit Claude makes:
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

## 4. Connect Codex to GitHub (the PR reviewer)

This needs a paid ChatGPT plan (Plus or higher; see [Prerequisites](../README.md#prerequisites)).

1. Go to **https://chatgpt.com/codex** and sign in with the same ChatGPT account the Codex CLI uses.
2. **Connect GitHub** when prompted. This installs the **ChatGPT Codex Connector** GitHub app.
   - Under *Repository access*, choose the repos Codex may see: *Only select repositories* is safest.
   - To add a repo later: **GitHub → Settings → Applications → ChatGPT Codex Connector → Configure**.
3. **Create an environment for the repo** at https://chatgpt.com/codex/settings/environments. The defaults are fine for review. Add setup commands only if you also want Codex cloud to run your tests.
4. **Turn on code review:** open Codex settings → **Code review**, then:
   - turn on **Code review** for the repo
   - turn on **Automatic reviews**, so every new PR is reviewed without a comment

   The kit relies on both. The PR loop posts `@codex review` after each fix push and expects the first review to happen automatically.
5. **Test it:** open a small PR and wait. Codex reacts with 👀, then posts a review, or a 👍 reaction when it finds nothing. Commenting `@codex review` should do the same.

Official docs: [Use Codex with GitHub](https://learn.chatgpt.com/docs/third-party/github) and [Codex cloud](https://learn.chatgpt.com/docs/cloud).

**How Codex reads your rules:** Codex reads `AGENTS.md` at the repo root, both locally and for PR reviews. The kit's template puts its review rules there, including the requirement to mark every finding blocking or edge case, so you don't configure anything else.

## 5. Notifications

Unattended mode tags you with an `@mention` and assigns the PR to you when a PR is ready. To actually see those:
- **Settings → Notifications** on github.com: turn on **Participating, @mentions and custom**, by web and mobile.
- The GitHub mobile app gives you a push notification for each tag.
- Claude Code also sends a push notification when the loop stops, if you've enabled notifications in Claude Code.

## 6. Labels and milestones

`/sdlc-init` creates these for you. By hand:
```bash
scripts/labels.sh path/to/repo
gh api repos/OWNER/REPO/milestones -f title="M1 — First usable slice"
```

## Checklist

- [ ] Issues are on, and head branches are deleted automatically
- [ ] Default branch protected: PR required, 0 approvals when solo, force pushes blocked
- [ ] `gh auth status` shows the `repo`, `workflow` and `read:org` scopes
- [ ] Git `user.name` and `user.email` are set
- [ ] ChatGPT Codex Connector has access to the repo
- [ ] Codex environment created; **Code review** and **Automatic reviews** turned on
- [ ] A test PR got a Codex review or a 👍
- [ ] @mention notifications reach you
