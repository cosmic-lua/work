## Evidence

`«MsXN_oznh»` (PR #1797) folded `_build/casts_test.tl`'s cast-kind
classification into `--check lint`'s `cast-justify` rule and deleted
`_build/casts_test.tl` — but that item's own stated scope was one
Method-section sentence in `docs/design/casts.md` plus the files it
directly touched; several other references to the now-gone mechanism
were left stale, one sentence or one comment away from each edit that
item actually made:

- `3p/tl/tl_patch/cast.tl:73` — a comment inside the carried tl patch
  references `_cli.lint.cast_lines` (deleted by `«MsXN_oznh»`, since
  the rewritten `check_cast_justification` no longer needs a
  lexer-only line finder) and `cast-sites.tsv` (already removed by an
  earlier item, per that same comment's own history — see `«NPTx_ycXD»`,
  a sibling item that already reworded a DIFFERENT stale reference to
  the same deleted tsv in this same file's comment, but not this one).
- `docs/design/casts.md`'s Method section, the sentence immediately
  after the one `«MsXN_oznh»` was scoped to edit, still reads
  `cosmic.ast, parsing real source, has no such confusion; _cli.lint.cast_lines(content, file)
  is the same lexer --check lint's cast-justify rule uses` — `cast_lines`
  no longer exists and the rule no longer uses a lexer at all (it
  parses with `cosmic.ast`, matching the sentence's own first half).
  The same section's closing sentence ("every cast matches exactly one
  kind … a site matching two names both") also no longer describes the
  rule's real behavior — `«MsXN_oznh»`'s own Change explicitly made it
  pass on ANY match, not exactly one.
- `_build/casts_kinds.tl:25` and `_build/casts.tl:4` — doc comments in
  each still name `_build/casts_test.tl` as what checks the allowlist
  against a fresh tree walk; that file no longer exists.

## Change

Reword each of the four sites above to describe the current mechanism
(`--check lint`'s `cast-justify` rule in `_cli/cast_lint.tl`, per-file,
via `cosmic.ast` parsing, no ceiling/exactly-one-match language) instead
of the deleted `_build/casts_test.tl`/lexer-based `cast_lines`. For
`3p/tl/tl_patch/cast.tl:73` specifically: read `«NPTx_ycXD»`'s own
already-landed (or in-review) rewording of the adjacent stale reference
in the same file first, and match its style/approach (state the
invariant directly rather than naming whichever module currently plays
the role, per `docs-style`'s guidance that a JUSTIFICATION comment
should be self-contained, not a pointer to a file that can go stale
again) — don't duplicate work if `«NPTx_ycXD»` already touches this
exact line.

## Non-goals

Not re-auditing the whole tree for every other reference to
`_build/casts_test.tl`/`cast_lines` beyond the four sites named above
— those were the ones the sibling item's own out-of-scope report
surfaced; if this item's own `grep` turns up more while fixing these,
fix them too (it's the same class of edit), but don't go looking
beyond what a full-tree `grep -rn "cast_lines\|casts_test\.tl"` finds
today.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
