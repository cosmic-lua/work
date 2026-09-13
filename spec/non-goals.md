- **The coverage line-mapping behaviour is frozen.** `walk`'s
  traversal, `exec_kinds`, and every `mark_statement` branch keep their
  current behaviour; only the TYPES move. `.cosmic-coverage` must not
  move, and it does not: with this change applied on this tree,
  `o/bin/cosmic --make coverage` ran 239 checks and printed
  `coverage ratchet ok` / `coverage: PASS (239 files)` with no edit to
  the committed floor. If it moves in your diff, the walk changed and
  the diff is wrong — do not regenerate the floor to make it pass.
- **Do not touch `_types/gentl.tl`** — not its erasure rules, not
  `RECORD_FIELDS`, not `PRELUDE`, not `KEEP`/`TO_STRING`/`NAMED`. The
  generated `tl.d.tl` surface does not move.
- **No tl pin bump.** `3p/tl/tl_pin.tl` stays at v0.24.8.
- **Do not widen `walk` to take `Node`,** and do not remove the three
  remaining casts at `:75`, `:87` and `:122`. Closing those needs a
  different mechanism and is not this slice.
- **Do not edit `docs/design/casts.md`.** Its tables are a snapshot
  dated `d3e59de7` and are already stale independently of this slice:
  measured 2026-08-25 against `1f9279ab`, 5 of the 13 rows in its
  "Any-map field walk" table name files that are gone or now carry zero
  from-any sites, the live rows sum to 22 against a stated total of 55,
  and the document's headline `192 of the 402` measures 111 of 314
  today (`git ls-files '*.tl' | xargs grep -h -- "-- cast: " | wc -l`,
  and the same piped through `grep -c "from any"`). Editing one row
  leaves the document neither current nor a coherent snapshot, and every
  sibling slice under this parent would collide on the same table.
  Refreshing it is its own item, filed as `3IQC4GeO`.
- **No change to any other file.** Not `_tool/coverage/report.tl`, not
  `baseline.tl`, and no test file: `_tool/coverage/lines_test.tl`'s 8
  test functions pass unchanged against the new types.
