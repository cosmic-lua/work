- **No `root $PWD` and no repo-root manifest anywhere.** That is the
  rejected shape; the treeroot's emptiness is the fix and
  `_perf/baserun_test.tl` is what holds it.
- **No `--include-dir .`** in the guard or anywhere else — measured to
  defeat it silently.
- No change to `cosmic/searcher.tl`, the `--modules` manifest format,
  `_cli/**`, `_make/**`, or `bin/cosmic.pin`.
- No change to `_perf/compare.tl` — its `format` signature is
  `3IUBNQZZ`'s to widen. This item only removes the wall.
- No scenario, `check()`, threshold, bar or noise-floor change. In
  particular `codec_base64_roundtrip_64k` keeps its floor, and
  `_perf/compare.tl:115-121`'s missing-scenario rule is not touched.
- No change to the `peers` job: it runs the CANDIDATE artifact, so it
  carries no skew (measured, Evidence 5).
- No change to `3p/tl/tl_patch/**` or `_make/patch.tl` — live siblings
  `3IVSDpFq` (#1477), `3IVZsiwL` (#1478), `3IVenbbU` (#1479).
- No rewrite of `docs/design/make/resolution.md`; its table describes
  BARE runs and stays true.
- No decision record: a lane is being made to measure what it always
  claimed to measure.
- No attempt to guard the `cosmic`-on-old-`cosmo` surface (below) —
  naming it is this item's job, guarding it is not.
