Not a locking/consensus redesign for the board — git's own
fast-forward check is already the correctness mechanism; the gap is
only that a caller sharing a stale local checkout can silently produce
an ORPHANED LOCAL commit instead of a clean, visible refusal to retry.
