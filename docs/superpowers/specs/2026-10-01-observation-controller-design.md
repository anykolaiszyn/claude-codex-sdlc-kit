# Observation-only SDLC controller — design (phase 1)

Status: approved scope. This is phase 1: a read-only observer, not an executor.

## Goal

Poll one GitHub repository and report, as structured JSON, what the SDLC process *would* act on — without acting. Identical consecutive polls print nothing (so an unchanged poll costs no model tokens downstream).

## Non-goals

No worker/agent launch, no fallbacks, no merging, no GitHub or git writes, no LLM calls, no scheduler, webhook server, database, or board. GitHub issues stay the source of truth; the observer's state is private execution metadata.

## Design

- `scripts/sdlc_observer.py` — stdlib-only. Reads through `gh api --method GET --hostname github.com` with argv lists, a fixed endpoint allowlist, validated owner/repo/login values, a timeout, and manual pagination that fails closed when a collection is malformed or truncated.
- Collect (all-or-nothing): open PRs and open non-PR issues; per PR the formal reviews, inline review comments, issue comments, reactions on the latest review-request comment, and current-head check-runs plus commit statuses. PR identity is read before and after; head/base/state drift triggers one retry, then failure.
- Normalize: keep only what the process needs (ids, shas, states, content hashes, short sanitized summaries). No polling timestamps, no human comment bodies.
- State: one versioned JSON file bound to repo+reviewer+requester, written atomically (temp file + `os.replace`) under an OS-level exclusive lock. Corrupt or mismatched state is an error, never discarded. Any failed collection leaves prior state untouched.
- Diff: the first run reports a baseline; later runs report only meaningful changes. Output is printed before state is saved (at-least-once), so a crash can repeat an alert but never lose one.

## Evidence rules

- A formal review receipt is current only if authored by the trusted reviewer, `commit_id == head`, and the base sha is unchanged since the receipt was first observed. Head or base changes invalidate old receipts.
- Findings are keyed by `pull_request_review_id:comment_id` plus content hash, never by the inline comment's `commit_id`. They persist across head changes and are always reported as triage-unknown.
- Plain bot comments and reactions are advisory. They bind to a revision only through an exact review-request comment whose head the observer itself witnessed (first seen while the previous poll saw the same head and base). Anything else is `unbound`.
- Checks are reported as `absent | pending | failed | passed`; provider quota/error comments are separate signals. None is ever called ready-to-merge or human approval. Labels are not owner approval.

## Testing

`tests/test_sdlc_observer.py` mocks only `subprocess.run` (the `gh` boundary) with a fake GitHub that paginates, and drives `main()` end to end.
