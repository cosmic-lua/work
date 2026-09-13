- Do NOT add `record` or `interface` back to `table_kinded`, and do NOT
  delete the set to "simplify". Admitting a record is the option D32
  rejects; a diff that does it contradicts the record it ships beside.
- Do NOT touch entries `narrow-metatable-is` or `narrow-metatable-not`,
  or any part of `is_table_metatable` other than the three inserted
  lines.
- Do NOT change a `find` anchor anywhere in `3p/tl/tl_patch/`. An anchor
  must keep matching the pinned tl source exactly once; a pin bump that
  moves one is supposed to fail loudly, and that signal is not softened
  here. This entry's anchor is `invalid_from` and does not move.
- Do NOT touch any other entry or file in `3p/tl/tl_patch/`. In
  particular leave the loop-site work (3IVQJa0b, PR #1473), the
  assigned-scan shapes (3IVL5DSr, PR #1472), 3IVZsiwL and 3IVenbbU
  alone.
- Do NOT touch `_make/patch.tl` or `_make/fetch.tl` (the mechanism is
  frozen by PR #1424), `3p/tl/tl_pin.tl`, or `bin/cosmic.pin`. No pin
  bump, no version change, no release staging.
- Do NOT close the VALUE-type unsoundness (`mt is {string: integer}`
  checking clean). It predates this slice, D32 records it as an accepted
  cost, and narrowing it is separate work with its own decision.
- Do NOT delete, weaken, reword or reorder the five existing metatable
  tests, beyond the single three-line comment at lines 334-336 that
  `Change` names. Do NOT touch any other test in the file.
- Do NOT touch `cosmic/fs/types.tl` (the tree's one production metatable
  is-dispatch site, an inline `mt is {string: any}` at line 248) or any
  other product source, and do NOT convert any site to a named alias to
  exercise the new rule. The source-side retires are 3IU5Vhvy's, gated
  on a pin bump.
- Do NOT hand-edit the derived table rows in `docs/decisions/README.md`;
  `_docs/derive.tl` owns them. Do NOT renumber, retitle, or amend any
  existing decision record.
- Do NOT raise the 500-line file cap or add an exemption for patch data.
