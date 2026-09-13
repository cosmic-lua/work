- `docs/decisions/d20-naming-charter.md`: append one final bullet,
  body above it untouched:
  `- **amended 2026-09 (iterator payload, #1643 review):**` — an
  iterator's `__call` returns only the loop value (`string`, no nil
  in slot 1); whatever the exhausted iterator has to say — `FileIter`'s
  subtree-error list, `LineIter`'s read failure — is read through a
  named accessor on the iterator after the loop, never by calling the
  iterator once more. Say what stopped being true (the
  `local _, errs = iter()` idiom recorded at `:126-141`), what
  replaced it, and that `LineIter` promotes from a bare function type
  to a callable record for it. Quote the decision text above as the
  provenance (records are exempt from the no-history rule).
- Line 4: `- **status:** amended 2026-09 (iterator terminating payload; earlier: the kept-POSIX set, rule 11)`.
- `bin/cosmic _docs/derive.tl` rewrites `docs/decisions/README.md`'s
  table from the H1 and status; commit it (`_build/docs_test.tl`
  fails on drift).
- Accessor NAMES are not decided here — `bj12_PZHY`'s build picks
  them under rule 1; the amendment states the shape only.
- `bin/cosmic --make ci` ends `ci: PASS` (the doc-citation lint reads
  the paths the bullet names).
