- **Do not change the formatter's output.** It is frozen: `cosmic
  --check fmt` must format the tree byte-identically before and after,
  which is what `--make ci`'s fmt stage over all 527 files already
  proves. This changes how comment tokens are TYPED, not how they are
  emitted, and no rule in `cosmic/format/rules.tl` is touched.
- **Do not bump the tl pin**, and do not change `gentl`'s erasure rules
  beyond adding `Comment` to the tables that name records — `erase`
  itself (`_types/gentl.tl:31`) is unmoved.
- **Do not touch the other five casts in `cosmic/format/init.tl`.**
  `:119`'s `token as Item` and the four `-- cast: tl declares number`
  reads are a different subject and keep their lines and their reasons.
- **Do not add any other record to `tl.d.tl`.** `Comment` is the one
  this slice needs; the coverage-AST case stays where it is
  (`3IOmhE0Z`), unreachable for the reason `Evidence` states.
- **Do not edit `_build/casts_baseline.tl` by hand**; run exactly the
  regen command the gate's failure message prints (`bin/cosmic --make
  run _build/casts.tl --baseline`) and commit the result.
- **Do not weaken a gate** any other way: no `.cosmicignore` entry, no
  coverage exclusion, no lint suppression.
- **Do not edit `docs/design/casts.md`** — it is a stale snapshot,
  tracked as `3IQC4GeO`.
- **Do not touch `whilp/cosmopolitan`.**
