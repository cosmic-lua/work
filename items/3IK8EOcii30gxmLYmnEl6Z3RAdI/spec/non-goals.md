- **The other two hypotheses in this item's original research note stay
  out of this diff.** (b) buffering a line and `table.concat`-ing it
  once instead of appending to `out` at 12 sites
  (`grep -c "out\[#out + 1\]" cosmic/format/init.tl` is 12), and (c)
  folding `mark_type_params`' per-line rescan (line 36, called at line
  271) into the single emit walk. Each is its own hypothesis with its
  own measurement; one commit, one hypothesis (`skills/optimize`).
  File them as board items rather than folding them in.
- **The output bytes do not move.** Not one file in the tree may format
  differently. Not a reformat, not a rule fix, not a new style.
- **Do not touch `3p/tl/**`, `tl.lex`, or `tl.parse_program`**, or the
  order they run in.
- **Do not change the `Item` interface in `cosmic/format/types.tl:28`**
  or any signature in `cosmic/format/rules.tl` — the rules module is
  typed against that interface and both files are shared with the type
  marking passes.
- Do not rename, delete, or weaken `format_module_source` or its
  `check` (`_perf/bench/format_bench.tl:58-79`, which pins `ok = true`
  and idempotence); do not commit `o/perf/*.json`.
