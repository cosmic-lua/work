- **No behavior change at any site.** Messages, error levels, exit
  codes (126/127 are the parent's contract in `child` and
  `quicksand`), and control flow are all frozen; this diff outside
  docs is comments only.
- **No lint.** Enforcement of the `-- throws:`/`-- exits:` grammar is
  the follow-up item named under Enablement, sequenced the way
  `-- assert:` (D23 amendment) preceded its lint (3IRTkNx1).
- **`cosmic/check.tl` and `cosmic/rand.tl` untouched** — their
  exemptions are D23's and D22's, module-level, already recorded.
- **No D23 or D22 edit.** D30 references them; their bodies and
  statuses do not move.
- **No conversion of `hash.tl`'s `error(` sites to `assert`** or any
  other respelling — recording, not refactoring.
- **Frozen:** the `-- cast:` and `-- assert:` grammars and their
  lints; `_docs/derive.tl` and the H1 index grammar; the census
  pattern above is the follow-up lint's spec input, not something this
  slice commits as code.
