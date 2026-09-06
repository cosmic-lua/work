## Evidence

2026-09-06, item «kTNP_QIG7»: the orchestrator ran `gitboard spec ID
FILE --base BASE --session <label>` with a FILE whose body was
byte-identical to the board's (a `sed` that had not matched). The verb
answered `gitboard-spec: 3Ixi1xY9's spec replaced` and committed —
but the commit touched only `meta` (a `speccers:` line); `spec.md`'s
blob was unchanged. The orchestrator then told a round-2 reviewer the
spec was amended; the reviewer proved from the item ref that it was
not (4 tool calls), and `verdict` correctly refused the unchanged
head+spec — a 12-minute review round with no verdict. A later retry
with a genuinely identical body said `nothing to record: spec 3Ixi1xY9
leaves the board unchanged`, so the unchanged case is already
detected somewhere; the first call slipped through because the
speccers bookkeeping counted as a change.

## Change

`_work/gitspec.tl` (the `spec` verb): compare the incoming body to
the stored `spec.md` before writing. Identical body → no commit at
all and the verdict line `gitboard-spec: <id8>'s spec is unchanged —
nothing written` (exit 0), regardless of whether the session would
have been a new speccer. A changed body → today's path, and the
verdict line gains the size of the change: `gitboard-spec: <id8>'s
spec replaced (+N/-M lines)`. `_work/gitspec_test.tl`: an identical
body writes nothing and says unchanged; a one-line change says
`(+1/-1 lines)`.

## Non-goals

No change to `--base` compare-and-swap semantics or to who may write.
