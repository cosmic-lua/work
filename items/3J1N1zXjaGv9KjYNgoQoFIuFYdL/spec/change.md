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
