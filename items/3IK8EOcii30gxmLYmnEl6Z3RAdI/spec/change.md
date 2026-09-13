One hypothesis: **the formatter copies the token stream it already
owns**. `build_items` (`cosmic/format/init.tl:94-120`) allocates a fresh
`Item` table per token — `{y, x, tk, kind}` — for every one of the
module's tokens. Stop copying: annotate the lexer's tokens in place and
put the token tables themselves into the item list.

Measured cost of the copy, same probe: 2161 tokens cost **385 KB** to
copy into `Item` tables, against 2007 KB net allocation for the whole
`format` call on that source (`collectgarbage("count")` deltas around
the copy loop and around `format.format`).

In `cosmic/format/init.tl` (`wc -l` 383 today, 117 lines of headroom):

- `record Item is rules.Item` (line 28) already declares only the two
  fields the formatter adds — `_newlines`, `_tight_before` — over the
  `y`/`x`/`tk`/`kind` interface. `tl.Token` (generated,
  `o/_types/types_gen/tl.d.tl:22-28`) carries exactly `x`, `y`, `tk`,
  `kind`, `comments`, so a token satisfies that interface as it stands.
  In `build_items`, replace the per-token table constructor with the
  token itself: `items[#items + 1] = token as Item`, carrying a
  `-- cast: the lexer's tokens are the formatter's after parse; Item
  adds fields, it does not reshape them` justification.
- Keep everything else in `build_items` as it is: the `$EOF$` skip, and
  the comment items, which are built from `token.comments` entries
  (`{string: any}`, four casts today) and have no table of their own to
  reuse.
- Nothing else changes. The two fields the emit pass writes
  (`item._newlines` at lines 209 and 324, `item._tight_before` in
  `mark_type_params` at line 57) then land on the token tables, which is
  safe by ORDER, not by convention: `tl.parse_program` runs at line 152
  and `build_items` at line 170, so the parser has already read the
  stream before the formatter writes to it, and `tokens` is a local that
  leaves `format` only through the items list.

**Ratchets this diff moves.** `cosmic/format/init.tl` is at 8 casts in
`_build/casts_baseline.tl:63`, and this adds one. When
`_build/casts_test.tl` fails on it, run the command that gate names —
`bin/cosmic --make run _build/casts.tl --baseline` — commit the
regenerated baseline, and justify the +1 in the PR description. Do not
weaken the gate any other way.
