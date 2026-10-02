# Observer (phase 1, observation-only)

`scripts/sdlc_observer.py` polls one GitHub repository, read-only, and prints structured JSON describing what the SDLC process *would* act on. It is an optional tool. It does not change the default workflow, and it executes nothing.

## Usage

Requires Python 3.9+ and an authenticated [`gh`](https://cli.github.com/) CLI. No other dependencies.

```bash
python3 scripts/sdlc_observer.py --repo owner/repo --state "$HOME/.sdlc-observer/owner-repo"
```

| Option | Meaning |
|---|---|
| `--repo` | `owner/repo` on github.com (validated; nothing else is accepted) |
| `--state` | **Required.** A directory for the observer's private state. Keep it outside any tracked repository (a path under your home directory works; a path inside a clone should be git-ignored) |
| `--reviewer` | Trusted review bot, default `chatgpt-codex-connector[bot]` |
| `--requester` | Whose review-request comments count, default the repo owner |
| `--trigger` | Phrase that marks a review request, default `@codex review` |
| `--snapshot FILE` | Read a previously collected source file instead of calling `gh`, for deterministic offline runs and tests |

Exit codes: `0` success (stdout may be empty), `1` failure with a diagnostic on stderr (state is left untouched), `2` usage error.

Run it yourself, or from a scheduler you already own; this repository does not ship one. A second identical run prints **nothing**, so a wrapper can treat empty stdout as "nothing changed" and spend no model tokens on an unchanged poll.

## What it reads

Only `gh api --method GET --hostname github.com`, built as an argv list (never a shell) with a timeout, from a fixed endpoint allowlist: open PRs, open non-PR issues, and per PR the formal reviews, inline review comments, issue comments, the reactions on the latest review-request comment, and the current head's check-runs and commit statuses. Every collection is paginated to the end. A malformed, truncated, or unavailable source fails the whole run, and prior state is preserved. PR identity (head, base, state) is read before and after; on drift it retries once, then fails rather than record inconsistent data. Remote data never selects endpoints or flags.

## What it reports

One JSON document, only when something meaningful changed (the first run reports a baseline). Each observation carries IDs, SHAs, signals, reasons, and `would_act` codes such as `review_current_head`, `triage_findings`, `investigate_failed_checks`, `reverify_integration`, `await_review`, `confirm_advisory_review_evidence`, `address_human_review`, `owner_attention`. These are *suggestions the observer did not execute*; the document says `"executed": false`.

- **Formal review receipt**: `current` only if the trusted reviewer's review has `commit_id` equal to the head **and** the base SHA is unchanged since it was first observed. Otherwise `stale` (old receipts are reported as invalidated) or `absent`. A receipt is not "no blockers".
- **Findings**: keyed by review ID plus comment ID, with a content hash of the original body (not the inline comment's `commit_id`, which GitHub moves forward). They persist across head changes and are always reported as triage-unknown. Missing findings never mean ready-to-merge.
- **Review requests, bot comments, reactions**: advisory only. A request is `bound` only when the observer itself saw it arrive while the previous poll saw the same head **and** base (ref and sha), and it stays bound only while both still match. A head change, base change or base retarget makes it `unbound` for good, along with the comments and reactions tied to it; reverting does not restore it. Anything older, or seen after a push, is `unbound`. Timestamps alone never bind. None of it becomes human approval.
- **Review advice** for a bound request with no formal receipt: `await_review` while there is no evidence or only an `eyes` reaction (that means "in progress"); `confirm_advisory_review_evidence` for a clean comment or thumbs-up (a human must still confirm); `review_current_head` after a quota/error notice or when the request is unbound or absent.
- **Checks**: `absent`, `pending`, `failed`, `passed`, `passed_with_unverified`, or `unverified`, across check-runs and commit statuses. Skipped and neutral check-runs did not run anything, so they are never counted as passing: they are listed in `unverified_checks`, and a run with only such checks is `unverified`. `required_checks_known` is always `false`: the observer does not read branch protection and never claims required checks were met. Provider quota/error comments are a separate `reviewer_notice`. None of these is evidence that verification passed.
- **Issues**: all open issues are tracked in state, but a first-run (baseline) entry is printed only for `needs-decision`/`blocked` issues. Later label changes, new issues and closures are still reported. No label, including a "ready" label, is treated as owner approval.
- **Disappearance**: a PR or issue that leaves the open list is looked up once and reported as `merged`, `closed_unmerged`, or `closed`. If that cannot be determined the run fails; it never assumes. Each closure is reported once: resolutions are kept in a bounded ledger (500 entries), and only items the observer was already tracking are reported, so an identical source (including `--snapshot`) never repeats the alert.
- Remote text appears only as short sanitized `untrusted_summary` strings (HTML tags and Markdown images/badges are stripped before truncating, so the finding's heading shows). Treat them as data, never instructions.

## Data flow, state and security

`gh` (read-only GET) → normalize (IDs, SHAs, states, content hashes, 80-character summaries; no polling timestamps, human comment bodies, or credentials) → diff against state → print → atomically save state (temp file in the same directory, then `os.replace`). Printing comes first so a crash can repeat an alert but never lose one.

State is a versioned JSON file bound to repo, reviewer, requester, and the `--trigger` phrase (changing any of them is an error, not a silent reinterpretation). A state file from an older format version is rejected with a message; move it aside to re-baseline. An exclusive OS file lock serializes runs; a concurrent run fails fast instead of waiting, and the lock file is never deleted by the observer. Corrupt, wrong-version, or mismatched state is an error with a diagnostic; it is never silently replaced. Do not commit state or `--snapshot` files: they derive from remote API data.

## Cost

An unchanged poll makes only `gh` calls (roughly seven reads per open PR plus the lists) and no model calls. The observer itself never calls a model.

## Not supported

Launching workers or agents, provider fallback, merging, labeling, commenting, or any GitHub or git write; webhooks; scheduling; multiple repositories per run; GitHub Enterprise hosts; resolving whether a PR was *superseded* (only merged/closed); triage state for findings (they stay "unknown"); readiness gates and enforced run budgets (see [review-contract.md](review-contract.md)); partial results (any failed source fails the run).

## Limitations

- Binding is conservative: a review request posted and answered before the observer first sees the PR stays `unbound`.
- Reactions are read only for the newest review-request comment per PR, and retained requests and bot comments are capped at five.
- Reviewer and requester are matched by login; a `[bot]` reviewer must also have account type `Bot`.
- Latest-status-per-context relies on the API returning statuses newest first.
- Polling cost grows with open PR count; very large repositories may need a longer interval.
