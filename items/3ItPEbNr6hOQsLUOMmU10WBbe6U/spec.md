## Evidence

Five `_build/` ratchets each walk the tree, lex or scan the sources, and keep their own
committed answer in their own format:

```
$ grep -rn "fs\.find(\|open_dir" _build/*.tl | grep -v _test | cut -d: -f1 | sort | uniq -c
      1 _build/cast_sites.tl
      1 _build/casts.tl
      1 _build/dupes.tl
      1 _build/nil_returns.tl
      1 _build/public_surface.tl
      1 _build/size.tl
$ grep -rln "tl\.lex(" _build _cli _tool --include=*.tl | grep -v _test | wc -l
8            (_cli/lint, assert_lint, throw_lint, pattern_args, nilreturn, returns; _tool/discover, _tool/coverage/lines)
$ wc -l _build/*_baseline.tl docs/design/*.tsv | tail -1
  674 total   (casts_baseline, nil_returns_baseline, public_surface_baseline, cast-sites.tsv, nil-flow-sites.tsv)
```

The duplication is measurable in prose too: the exact-duplicate census (the prose
gate item) finds `_build/casts.tl` and `_build/nil_returns.tl` sharing three identical
doc paragraphs (lines 31/40, 38/44, 95/169: the trees covered, the committed floor,
the rewrite command) — two ratchets that are one mechanism over two token kinds, kept
apart because each owns its walk and its file format. `docs/design/cast-sites.tsv`
carries a curated `class` column beside generated `path`/`line` columns and needs its
own `--reconcile` verb (`_build/cast_sites.tl`, 204 lines) to survive a regeneration.

A derived database is the shape that removes the walks: one generation of the tree
into tables — `file(path, kind, lines, sha)`, `token(path, line, col, kind, text)`
from `tl.lex`, `definition(path, line, name, kind)` from `tl.parse_program` the way
`_tool/discover.tl` already reads function extents, `doc_block(path, line, text)` —
and every ratchet becomes a query: casts are `SELECT ... FROM token WHERE text='as'`,
nil-returns a join, the public surface a query over `file`, the site inventories a
view whose curated column is the only thing left committed. The build already has the
slot: `*_gen.tl` generation units run before the graph (`_types/types_gen.tl`), and
the checker, compiler and formatter read what they produce.

What is NOT known, and what this item measures: the cost of the token table. The
prose-only index built in 266 ms (4,876 blocks, 714 files); a trigram FTS index over
all 4.6 MB of `.tl` source built in 720 ms at 16 MB, which is the wrong table but an
upper bound on "index the bytes"; a `tl.lex` token table (roughly 1.3M tokens by size)
is unmeasured, and a generator that costs more than the ratchets it replaces is a
loss. The decision also touches settled ground — the constant-rules-generated-facts
rule for `o/project.mk`, D16's enumerable build inputs, D27's one committed floor — so
it is a decision record (the `decide` skill), not a refactor.

## Change

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

## Non-goals

Moving `_cli/lint`'s per-file rules onto the db — `--check lint <file>` runs on ONE
file with no build, and a lexer pass per file is its correct cost. Replacing the
committed baselines. Any change to `o/project.mk` or the `embed/cosmic.mk` rules.
Shipping the db in the artifact.
