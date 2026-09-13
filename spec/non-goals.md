- **Do not rewrite either comment and keep its map view.** That was the
  shape this item was filed as; the Evidence below shows the tolerance is
  inert under the oldest binary the guard promises, so the honest change is
  the deletion. A comment explaining a mechanism that does nothing is worse
  than the wrong comment it replaces.
- **Do not touch `_perf/skew_test.tl`'s mechanism.** Its argv, its
  `perf_only_include_dir`, its bootstrap assertion and its file sweep are
  the gate that makes these typed calls safe. Only the three literal_bench
  mentions and the sentence carrying them change; do not weaken, skip, or
  delete the test, and do not audit the rest of its prose here.
- **No change to the lane or its callers**: `_perf/baserun.tl`,
  `_perf/baseline.tl`, `_perf/gate.tl`, `_perf/compare.tl`,
  `.github/workflows/release.yml` are all out of scope. `_perf/gate.tl` and
  `_perf/compare.tl` in particular have open PRs against them (#1485,
  #1486); this slice must not touch them.
- **No results-file schema change.** `pt.Meta.cosmic_version` and
  `pt.Meta.cosmos_version` stay optional and stay absent when
  `version_info()` returns nil. No placeholder word is ever written into
  them, which is the doctrine the paragraph at `_perf/run.tl:133-140`
  states for `bin_sha`.
- **No scenario, threshold, check, or noise bar moves.**
  `literal_format_floor_compact` keeps its name, its position (index 3),
  its `verify` arguments, and its input. This is not a perf change and
  makes no timing claim.
- **Do not touch `docs/design/make/resolution.md`.** It cites
  `_perf/run.tl:163` as an inline citation, which the citations lint
  resolves by position only; run.tl stays 394 lines, well past 163, so the
  lint still passes. Its prose names `pcall(require, name)`, which is at
  `_perf/run.tl:175` today and would move to `:164` — already stale before
  this slice and not this slice's business.
- **No new `as` cast anywhere in the diff**, and no `-- cast:` comment left
  behind without its cast.
