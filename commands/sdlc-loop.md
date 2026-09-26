---
description: Start the unattended PR follow-up loop — triage Codex reviews, fix blockers, backlog edge cases, then pick the next eligible issue
argument-hint: "[PR numbers to watch]"
---

Invoke the `loop` skill in dynamic mode (no interval) with this prompt, verbatim apart from the PR list:

> Run the PR follow-up loop and unattended mode from docs/DEVELOPMENT-PROCESS.md (skill pairing-with-codex-cli). The steps below describe the default Codex path; which provider actually runs the review/gate is decided by the `pre_pr_review`/`pr_gate` roles in `.claude/agents.json` (see docs/DEVELOPMENT-PROCESS.md → Provider assignment). Watch these PRs: $ARGUMENTS (if none are given, use every open PR by this user with an unanswered Codex review or a pending "@codex review"). Each wake:
- **Triage** Codex reviews submitted since the last triage. Match comments by `pull_request_review_id`. Probe each finding, then:
  - **blocking:** TDD fix, push, reply, then re-post "@codex review"
  - **valid non-blocking:** open a backlog issue and reply with its link
  - **invalid:** reply with the evidence
- **Stop a PR** on 👍, a round with no blocking findings, or 3 fix rounds. Post a summary comment that @mentions the user, assign the PR to them, and send a push notification. On a solo setup, the push notification is the only alert the user gets, because GitHub doesn't notify people about their own activity.
- **Pick the next eligible issue:** labelled `bug`, `edge-case` or `process`; not `blocked` or `needs-decision`; no open "Depends on". Take it through a design comment on the issue, a worktree, TDD, a local Codex review, and a PR.
- **When nothing is looping and nothing is eligible:** stop the loop, send the user a push notification, and list what's waiting for them.

Keep a ledger in `.superpowers/loop/progress.md` so the loop survives context compaction.
