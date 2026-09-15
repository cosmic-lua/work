`refresh` (and its deprecated alias `sync`) prints one `current-claim` line per
claim on the board, whatever that claim's status, ahead of every other output.
On today's board that is 123 lines and every one of them is expired:

    bin/gitboard sync > sync.txt 2>&1
    grep -c "^current-claim" sync.txt          -> 123
    grep -c "status=expired" sync.txt          -> 123
    grep "^current-claim" sync.txt | grep -vc "status=expired"  -> 0

So the block costs 123 lines to carry zero bits: an expired lease confers no
authority, which is the one thing this report exists to state — its own doc
comment reads "Refresh reports current authority independently of historical
publication proof" (`grep -n "Refresh reports current authority" _work/stateclaim.tl`).

The renderer is `authority` in `_work/stateclaim.tl` —
`grep -n 'lines\[#lines + 1\] = ("current-claim %s status=%s holder=%s' _work/stateclaim.tl`.
It appends a line for every id in `view.claims_by_id` with no reference to
status, while computing that status inline for the format string.

Change `authority` to hoist the status, and emit a line only for a claim whose
status is not `"expired"`. The `Status` enum is declared in `_work/claim.tl`
(`grep -n "local enum Status" _work/claim.tl`) as `"none"`, `"active"`,
`"expired"`, `"future"` — only `"expired"` is suppressed, so a `"future"` or
`"none"` claim still prints, those being anomalies a reader must see.

Count what was suppressed and append one trailing line, `expired-claims=N`,
when N is greater than zero. Keep the existing `current-claims=0` return for a
board with no claims at all
(`grep -n 'or "current-claims=0"' _work/stateclaim.tl`); a board whose every
claim is expired therefore renders exactly `expired-claims=123` in place of
today's 123 lines.

Regression: extend `_work/stateclaim_authority_test.tl` with a case holding one
active and two expired claims, asserting the output carries the active claim's
`current-claim` line, no line for either expired one, and `expired-claims=2`.

No tracking file moves: `_work/stateclaim.tl` has no `.cosmic-coverage` row —
`grep -n "stateclaim" .cosmic-coverage` returns nothing against 91 rows
(`grep -c '\["_' .cosmic-coverage`), and the file is not in `.cosmicignore`,
so the ratchet simply does not carry it today and this change adds no row.
