- **The output bytes do not move.** Not one file in the tree may format
  differently. Not a reformat, not a rule fix, not a new style. The
  `fmt` stage of `--make ci` is what enforces this over every tracked
  source, and it is Acceptance 1.
- **Do not clear or reallocate `buf` per line** (`buf = {}`, a
  `for i = 1, #buf do buf[i] = nil end` loop, or `table.move`). The
  reuse plus the bounded concat IS the change; clearing gives the
  allocation back.
- **Do not fold in the other emit hypotheses.** `mark_type_params`'
  per-line rescan is board item **3IM89sc3**; the token-copy removal in
  `build_items` is **3IK8EOci** (PR #1353, in review as this was
  written). One commit, one hypothesis (`skills/optimize`).
- **Do not touch `cosmic/format/rules.tl`, `cosmic/format/types.tl`, or
  `3p/tl/**`**, and do not change the order in which `tl.lex`,
  `tl.parse_program` and `build_items` run.
- Do not rename, delete, or weaken `format_module_source` or its `check`
  (`_perf/bench/format_bench.tl:58-79`, which pins `ok = true` and
  idempotence); do not commit `o/perf/*.json`.
- Do not add an `as` cast. The prototype needed none, so a cast in this
  diff means the shape drifted from what was verified.
