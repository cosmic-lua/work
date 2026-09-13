Research; the deliverable is a decision record and its follow-up items, with the
numbers below in it. Handover with `--result`.

1. **Prototype, in `o/`, thrown away.** A `_build/tree_gen.tl`-shaped script that
   lexes every model source (`_make`'s `lint_sources` set, not a directory walk —
   `CLAUDE.md` is a symlink and `testdata/` is excluded by the model) into an
   in-memory `token` table plus `definition` and `doc_block`, then writes it to
   `o/tree.db` (WAL off, `journal_mode = OFF`, one transaction). Measure and paste:
   wall time cold, file size, and the time for the two queries that reproduce
   `_build/casts.tl`'s count and `_build/nil_returns.tl`'s count. The counts must
   equal the committed baselines exactly (`_build/casts_baseline.tl`,
   `_build/nil_returns_baseline.tl`) — paste both comparisons.
2. **Decision rule, stated before measuring.** Adopt when (a) the generator runs
   under 2 s on the CI lane's hardware class (a cold `--make ci` already spends
   minutes, and this runs once per gate, not per file); (b) `casts.tl` and
   `nil_returns.tl` rewritten as queries are shorter together than today's 364 lines
   with their three shared paragraphs stated once; (c) incremental is possible — a
   file's rows are keyed by its sha so an unchanged file is skipped, the same rule
   `_tool/doc/index.tl`'s inputs follow. Otherwise record why and end the line.
3. **The record.** On adopt: `docs/decisions/d<next>-<slug>.md` in the four-section
   form, H1 in the index grammar, status `standing`, recording: the db is DERIVED and
   never committed (the `o/project.mk` rule: generated facts, constant rules); every
   ratchet's committed floor stays a `_tool/floor` literal — the db is how a count
   is produced, never where it is kept (D27); the curated `class` column of
   `cast-sites.tsv` is the one committed table, and the generated columns become a
   view joined to it. Run `bin/cosmic _docs/derive.tl` so the decisions index carries
   the row.
4. **Follow-ups filed, blocked on the record:** (a) `_build/tree_gen.tl` as a
   generation unit with `_build/tree_gen_test.tl` asserting the two counts against
   the baselines; (b) `casts.tl` and `nil_returns.tl` as queries over it, their three
   shared paragraphs moved to `_build/ratchet.tl`; (c) `cast_sites.tl`'s
   `--reconcile` replaced by the view; (d) the prose-duplicate gate and the
   doc-symbol gate (filed beside this item) re-pointed at `doc_block` once it exists.
   Each names its files; none is started before the record lands.
