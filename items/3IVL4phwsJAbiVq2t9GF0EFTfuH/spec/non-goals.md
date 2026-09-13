- Do NOT make record, interface, or type-alias `is`-dispatch WORK. No
  `resolve_nominal` / `to_structural` call inside `is_table_metatable`,
  and no widening of the rescue past inline map and array literals.
  3ISSFrCO settled that a nominal resolving to a record must keep
  failing; reversing it is a new decision, not this slice. The fresh
  evidence for a future one — a named alias of a map is refused exactly
  like a record — is captured as 3IVSDpFq and must not be acted on here.
- Do NOT touch entries `narrow-metatable-is` or `narrow-metatable-not`,
  their `find`/`replace` strings, or the body of `is_table_metatable`.
  Only the `table_kinded` literal, the comment above it, and this entry's
  `note` move.
- Do NOT touch any other entry in `3p/tl/tl_patch/`. In particular leave
  the closure-carry narrow rule (3IVL3BLT) and the loop-site behaviour
  captured as 3IVQJa0b alone: this slice changes no live narrowing
  behaviour, in the tree or in any program.
- Do NOT change a `find` anchor anywhere in `3p/tl/tl_patch/`. An anchor
  must keep matching the pinned tl source exactly once; a pin bump that
  moves one is supposed to fail loudly, and that signal is not to be
  softened here.
- Do NOT touch `_make/patch.tl` or `_make/fetch.tl` (the mechanism is
  frozen), `3p/tl/tl_pin.tl`, or `bin/cosmic.pin`. No pin bump, no
  version change, no release staging.
- Do NOT delete, weaken, or reword the two existing metatable tests
  (`test_metatable_is_table_narrows`, `test_metatable_is_scalar_is_refused`,
  lines 287-332), and do NOT touch any other test in the file.
- Do NOT touch `cosmic/fs/types.tl` — the tree's one production metatable
  is-dispatch site (`mt is {string: any}`, line 248) — or any other
  product source. This slice adds no caller and removes none.
- Do NOT add docs or guide prose about metatable is-dispatch.
  `grep -rn 'table_kinded' docs/ AGENTS.md` → `0` hits today, and this
  slice leaves it at `0`; the patch entry's own comment is the
  documentation.
- Do NOT rewrite `3p/tl/tl_patch/narrow.tl`'s file header, split the
  file, or reformat unrelated entries.
