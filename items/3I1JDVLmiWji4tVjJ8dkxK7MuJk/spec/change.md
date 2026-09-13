One regen verb and one failure contract, written once over three gates that
by now share a reader.

- Add `bin/cosmic --make baseline [NAME]` in `_make/`: with no argument it
  regenerates every committed floor; with a name (`coverage`, `casts`,
  `surface`) just that one. `--make coverage --baseline` keeps working as an
  alias for the coverage case — CLAUDE.md and CI both name it.
- Every ratchet failure, in BOTH directions, ends with the exact command that
  regenerates its floor, and says what a legitimate justification is when the
  move is an increase. Today only `_build/casts_test.tl`'s DECREASE branch does
  (`REBASELINE`, line 26); its increase branch says "remove them, or justify
  the increase in the PR" and names no command.
- One failure shape across the three gates, so a session that has read one has
  read all three.
- Update CLAUDE.md's testing section and `skills/work/decompose.md`'s ratchet
  clause — it already tells a slice to "run exactly the regen command the
  gate's failure message prints", and this makes that instruction true for
  every gate in both directions.
