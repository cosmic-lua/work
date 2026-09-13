Convert `.cosmic-coverage` to the `cosmic.literal` format and make
`_tool/coverage/baseline.tl` read and write it through `_tool/floor.tl`,
deleting its own line scan, its `path covered total` split, its repeated-path
resolution and its canonical write.

- The floor becomes one `["path"] = { ["covered"] = C, ["total"] = T },` per
  line, sorted by path — the inline-nested-table layout `3I7BQPsM` adds to
  `cosmic.literal.format`, the same shape and sort the other two floors have,
  and a `cosmic --check fmt` fixpoint like them.
- The repeated-path rule survives unchanged in meaning: the lower percentage
  wins, expressed now as the `worse` resolver the helper passes to
  `on_duplicate`. Its comment in `.gitattributes` stays true and should be
  updated to name the mechanism rather than the hand-rolled parser.
- What stays coverage's own: the tolerances (`total_tolerance_pp`,
  `file_tolerance_pp`), the file-set drift check, and `lowered`'s rule that a
  rewrite lowers only the rows this run would have failed on. Those are
  judgment, and judgment stays in the gate.
- The conversion of the committed file itself is part of this diff: the same
  rows, the same numbers, a different encoding. State the row count before and
  after as a fact, and show that no row's numbers moved.
