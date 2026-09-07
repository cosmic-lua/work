## Evidence

In an environment without `GITHUB_TOKEN` or `GH_TOKEN`, every `gitboard sync`
prints the same warning:

    gitboard-sync: lanes: unknown (release.yml: no GitHub token: set GITHUB_TOKEN (or GH_TOKEN))

Measured repeatedly on 2026-09-07 while reading a board whose Git refs were
otherwise current. `_work/api.tl:273-275` returns the missing-token error and
`_work/lanes.tl:402` renders it on every sync. Once the session has established
that lane health is unavailable for this stable reason, repeating the full
warning adds no information and consumes orchestrator context.

This is distinct from a transient network error or a change from known lane
health to unknown: those transitions remain actionable and must be visible.

## Change

Suppress identical, stable lane-unavailable warnings after their first emission
for the board cache/session, while preserving state changes:

- Emit the full warning the first time a particular unavailability reason is
  observed.
- On subsequent syncs with the identical reason, emit no lane line (or one
  compact summary only when another sync result is printed).
- Emit again when the reason changes, lane observation becomes available and
  later fails, or an explicit verbose/diagnostic mode requests it.
- Do not persist a machine-specific missing-token condition into committed
  board refs. Any suppression state belongs in the disposable local cache.

Add tests around the lane observation/reconciliation seam for first occurrence,
identical repeat, changed reason, recovery, and failure after recovery.

## Acceptance

    GITHUB_TOKEN= GH_TOKEN= ./o/bin/cosmic _work/lanes_test.tl
    ./o/bin/cosmic --make test

The focused test demonstrates one full missing-token warning across two
consecutive sync observations, and a new warning after recovery followed by a
fresh failure.

## Non-goals

Do not hide red lanes, transient failures, or changed error reasons. Do not
change which workflows are observed or how GitHub authentication is obtained.
