Wire the checks that already exist into a test, and repair the drift.

**1. Repair the inventory.** Drop the five rows for `_perf/run.tl` and
`_perf/bench/literal_bench.tl`; the file becomes 210 lines. Re-derive
rather than hand-edit — `_cli.lint.cast_lines(content, file)` returns a
file's real cast lines and is what #1489 extracted with — and reconcile
the affected per-class counts in `docs/design/casts.md` prose.

**2. Add the gate**, as a test beside the existing build ratchets. It
must assert, against the committed baseline and the committed document:

- per-file counts agree (the check above), which subsumes the total;
- every class in column 3 has a `### ` heading in `casts.md`, and every
  heading has at least one row;
- every row's line holds a real cast, by `_cli.lint.cast_lines` rather
  than by grepping for the word `as` — #1489's row check used the grep,
  which passes on any line containing `as` in prose.

Its failure message must name the regeneration command, the way the
cast baseline's own failure does, so a session that lowers a cast count
is told in one line how to update the map.

**3. Decide whether the file is generated or curated, and say so in
`casts.md`.** Columns 1 and 2 are derivable; column 3 is a human
judgment that cannot be regenerated. So a full `--baseline` regen would
destroy the classification. Name the intended workflow — most likely
regenerate paths and lines, preserve the class for a site that still
exists, and fail loudly for a site with no class — and state it where
the document explains the file.
