- **Do not make `build` or `test` actually run fmt or lint.** Checking
  instead of recommending is a different, larger change with its own
  contract question (does `build` now FAIL on a fmt error?); it is not
  this slice, and this slice must not half-start it.
- **Do not widen which verbs print the note.** `example`, `benchmark`,
  `check`, `fmt` and `lint` also skip parts of the gate; the evidence
  is about `build` and `test`, and a note after every verb is noise.
  The predicate stays exactly the four conditions it has today.
- **Do not change any verdict line.** `_tool/records.tl`'s
  `format_verdict` grammar and `records.exit_code` are frozen —
  downstream scripts and CI parse `build: PASS` / `ci: FAIL (stages)`.
  `gate_note` returns its `code` argument unchanged; no exit code moves.
- **Do not change the converge suppression rule.** `COSMIC_MAKE_GEN`
  and `COSMIC_MAKE_STEP` keep their meanings and their readers; only
  the text they gate changes.
- **Do not edit `docs/guides/quickstart.md`, `docs/guides/make.md` or
  `docs/build.md`.** Their inner-loop advice is correct and this slice
  is the error-site countermeasure to it, not a rewrite of it.
- No new flag, and no environment variable to silence the note.
