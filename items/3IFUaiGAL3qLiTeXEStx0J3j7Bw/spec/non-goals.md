- wave 6b's ten `function shape` sites are not touched here.
- the 40 still-blocked sites are not touched, and no code is reshaped
  to make one of them pass. `cosmic/fetch/init.tl:220` carries TWO
  casts on one line and exactly one of them can go — leave the line
  alone; it is a blocked site, recorded as such in `3I7OygFC`.
- no tl patch work (`3p/tl/tl_patch.tl`).
- `_perf/bench/micro_bench.tl:191` is blocked as measured; a
  `check.must` rewrite would remove it but that is a different change
  and not this wave's.
- no change to what any of the 32 sites' surrounding code DOES: every
  one of the 27 plain deletions and the companion deletion is a pure
  removal, and the four restructures swap a guard spelling and nothing
  else. If a site does not check clean after its stated edit alone,
  main has moved — bounce the item rather than reshaping the code.
- the two new narrowing tests pin the checker's behaviour only; do not
  add cases for other types (primitives, records and arrays are already
  pinned by `test_early_exit_is_guard_narrows`).
