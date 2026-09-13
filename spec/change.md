In `_build/casts.tl`, add `"_eval"` and `"_fuzz"` to the `TREES < const >`
list (currently 9 entries, lines 33-36). Then regenerate the committed
floor: `bin/cosmic --make run _build/casts.tl --baseline`, and commit the
result — the two new trees' cast sites enter the ratchet at their current
count, so this slice is a one-line addition plus a baseline regen, nothing
else. No change to `_build/public_surface.tl`, `cosmic/literal.tl`, or the
gate's comparison logic.

The measured facts this rests on (2026-08-18, re-measured — the epic's own
2026-08-17 count of 14 sites is stale; three more sites landed in `_eval/`
since):

```facts
$ grep -n '"_eval"\|"_fuzz"' _build/casts.tl
$ git grep -c -- "-- cast:" -- "_eval/*.tl" "_fuzz/*.tl"
_eval/score.tl:10
_eval/score_test.tl:13
_eval/stage.tl:9
_eval/stage_test.tl:3
_fuzz/compress_fuzz_test.tl:1
_fuzz/sse_fuzz_test.tl:1
$ git grep -c -- "-- cast:" -- "_eval/*.tl" "_fuzz/*.tl" | awk -F: '{s+=$NF} END {print s+0}'
37
$ wc -l < _build/casts.tl
156
$ grep -oE '= [0-9]+' _build/casts_baseline.tl | awk '{s+=$2; n++} END {print s, n}'
418 130
```
