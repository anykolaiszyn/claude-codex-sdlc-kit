# Observation-only controller — plan

TDD vertical slices; each starts with failing tests (RED), then minimal code (GREEN).

1. **Boundary and state**: input validation, `gh` argv shape and allowlist, pagination and fail-closed handling, locked atomic versioned state.
2. **Baseline, idempotence, reviews**: baseline report, empty second run, restart, review receipts, finding identity, base/head invalidation.
3. **Triggers and evidence**: request binding, bot comments, reactions, checks, quota notices.
4. **Races, reconciliation, issues**: identity drift retry, closed/merged reconciliation, owner-attention issues, snapshot mode.
5. **Docs and CI**: `docs/observer.md`, `docs/review-contract.md`, links, CI step.
6. **Full verification**: bash suites, unittest, compile check, plugin validation.
