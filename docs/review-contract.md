# Next-stage review contract (proposal)

**Status: proposal for a future opt-in executor. Nothing here is shipped or enforced.** The existing workflow in [DEVELOPMENT-PROCESS.md](../template/docs/DEVELOPMENT-PROCESS.md) is unchanged and remains the default. This page describes what a later, explicitly opted-in stage should guarantee; it does not restate the current rules. The [observer](observer.md) is read-only and implements none of it.

## Principles

- **GitHub issues are the source of truth** for the product. Any controller state is execution metadata only: private, disposable, never a roadmap or board.
- **Opt-in per repository.** A repository that does nothing keeps today's behavior.
- **One review path per risk tier**, chosen by the tier already named in the PR (`Review budget: <tier> — <why>`), instead of stacking every reviewer on every change. A small team gets the review that matches the risk, not the maximum.

## Risk-based single-path review

| Tier | Review path |
|---|---|
| Low | Local checks and Claude's own final review (the narrow exception below). |
| Medium | Exactly **one** Codex path: either the local CLI **or** the cloud PR bot, never both by default. Which one is a repo setting. |
| High | The medium path, plus a senior Claude review that asks a *distinct* architecture/integration question, not a repeat of the Codex findings pass. |

Whoever implemented a change never provides its only review. In particular, **Codex-implemented work requires a distinct Claude review**, and Claude-implemented work gets the tier's Codex path.

**Narrow low-risk exception:** only genuinely low-risk work (typo fixes, comments, formatting-only changes, tiny non-runtime cleanup) may rely on the implementer's own final review without a separate reviewer. Being a documentation change does not make something low risk. Anything that changes operational procedure, process or policy, approval or review rules, security or permissions guidance, runtime behavior, or a public contract is at least medium, even when only prose changes. When in doubt, pick the higher tier. This matches the existing [Review budget](../template/docs/DEVELOPMENT-PROCESS.md#review-budget) table and does not change it.

## Provider chains

An empty or fully disabled provider chain does **not** mean "skip the review". Under the existing semantics ([Provider assignment](../template/docs/DEVELOPMENT-PROCESS.md#provider-assignment), [Failover and quota handling](../template/docs/DEVELOPMENT-PROCESS.md#failover-and-quota-handling)) it is treated like an exhausted provider: apply the review-budget and failover rules and surface it. A future executor must keep that behavior.

## Evidence

Receipts are revision-aware: a review counts only for the head and base it was made on, and head or base changes require fresh evidence. Advisory signals (bot comments, reactions, labels, passing checks) never become human approval. These are the same rules the observer reports against.

## Not in scope yet (future execution requirements)

- **Explicit readiness**: a stated, auditable definition of "ready for work" per issue (the observer treats labels as non-authoritative).
- **Enforced run budgets**: hard limits on runs, retries, and spend per issue and per period, with fail-closed behavior.
- Worker launch, provider fallback, merging, and any GitHub write.

Each needs its own design and approval before an executor is built.
