One decision by the goal owner, then one PR. Put the three wordings
in front of the owner with the numbers above (51 floor sites, 23 after
compression, the cast-legality refusal split), and land the answer:

- `docs/goals.md` G3 `measured by` / `win condition`: replace "zero
  `as` casts" with the chosen wording —
  1. literal zero, unchanged, with the sentence that the last 23 are
     reached by deleting what they serve;
  2. zero outside a declared floor, held per class in
     `docs/design/casts.md` and ratcheted per file by
     `_build/casts_baseline.tl`, test probes required to go through
     `check.is_exposed`/`check.refuses`;
  3. zero outside what the checker permits — `cast.tl`'s rule
     un-gated, `x as T` legal only from `any`, a `.d.tl` userdata, or
     the enclosing generic's type variable; refusals are the floor.
- `docs/design/casts.md` `## The floor`: rewrite the two counts to
  51 and the per-class split measured at merge time, keeping 23.
- Wording 3 additionally files (does not do) the un-gating work: one
  item per refused class from the census, blocked on a `bin/cosmic.pin`
  bump (a checker rule that refuses in-tree code is the cold-build
  case).
- `bin/cosmic --make ci` ends `ci: PASS` (`_build/docs_test.tl` and
  the doc-citation lint read both files).
