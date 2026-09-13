- No checker behaviour change. The loop drop is correct; this slice describes
  and pins it. Do not add, remove, reorder or re-word any `find` or `replace`
  string in `3p/tl/tl_patch/**` — those are the frozen anchors, and the derived
  `o/3p/tl/tl.lua` must come out byte-identical. No `--make fetch` step, no
  `bin/cosmic.pin` bump.
- Do not touch `3p/tl/tl_patch/narrow.tl` or `3p/tl/tl_patch/ast_cache.tl`.
  Item `3IVL4phw` (PR #1468) is editing `narrow.tl` right now.
- Do not touch `_make/patch.tl`.
- Do not modify any of the existing test functions in
  `cosmic/teal_closure_test.tl`, and do not touch `cosmic/teal_narrowing_test.tl`
  or `cosmic/teal_test.tl`.
- Do not split the closure boundary's body/continuation scan, or otherwise act
  on `3IVZsiwL`.
- No new lint, no `docs/guides/**` section, no decision record. The comment and
  the test are the whole deliverable.
- Board state stays on the board: `3IVQKRm2` is an unpromoted capture of this
  same observation and is not this diff's to close.
