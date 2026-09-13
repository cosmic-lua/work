- **No signature moves.** `fs.visit`'s `any` context, `_perf.harness`'s
  `any` scenario context and result, and the `_perf.types` records stay
  exactly as declared. This slice guards at the point of use; making a
  declaration honest is its sibling `3IOuS3IE` child and, for `fs.visit`,
  `3ILxnhaK`.
- **`_perf/run.tl:131` stays.** `rawget(arg, -1) as string` sits inside an
  `or` chain, so closing it restructures an expression rather than adding a
  guard; it is not this slice's uniform shape. `_perf/run.tl` therefore
  ends with one `from any` cast, not zero.
- **The lazy requires stay lazy.** `cosmic/quicksand/box/run.tl:68` and
  `cosmic/quicksand/box/init.tl:150` are deliberate cycle breaks; do not
  hoist either to a top-level `require`, and do not touch the comments
  that say why.
- **No new public module and no new export.** `_build/public_surface_baseline.tl`
  must not move.
- **Do not touch the other 34 `from any` casts.** 46 lines carry that
  reason today across 26 files (`git ls-files '*.tl' | xargs grep -h --
  "-- cast: " | grep -c "from any"`, and `... | xargs grep -l -- "-- cast:
  .*from any" | wc -l`, both at `c2ae0466`; two of the 46 are string
  literals in `_build/casts_test.tl` that the lexer-based counter does not
  count). The totals fell from 99/41 files as sibling slices landed; the
  twelve named above are untouched by any of them, and only they close
  here.
- **Do not touch `cosmic/sqlite/**` or `cosmic/fetch/**`.** They are the
  sibling child's files, and both slices rewrite `_build/casts_baseline.tl`
  — keeping the source files disjoint keeps the conflict to that one
  regenerated file.
- **Do not edit `docs/design/casts.md`** (a stale snapshot; `3IQC4GeO`
  owns it).
