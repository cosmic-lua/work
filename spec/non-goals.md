- No other `lpath.c` function moves: `basename`, `dirname`, the
  `CheckPath` family keep their contracts.
- No change to interior-nil skipping or empty-string coercion — the
  probes above pin both.
- No cosmic-side edit and no cosmos pin bump: that is the sibling
  consumption slice, blocked on this one.
- No drive-by edits in `definitions.lua` outside the join block, and
  no reformatting in `lpath.c` — the fork stays surgically mergeable.
