## Evidence

Exact-duplicate prose is a hash lookup (the sibling item that gates it). What a gate
cannot see is the paragraph pasted and then re-worded: same claim, different
inflections, one sentence dropped. Those are the copies that DISAGREE later, and the
tree has them — the `_build/casts.tl`/`_build/nil_returns.tl` pair shares three
byte-identical paragraphs (the exact gate's finding) and reads as near-identical for
most of its length.

FTS5 makes the near-duplicate question cheap to ask: index every prose block, then for
each block run its own distinct terms as an OR-query and take the best OTHER hit's
`bm25()` as a ratio of the block's own self-score. Measured 2026-09-05 at c39fc2f,
`o/bin/cosmic` built from the tree (FTS5 present; the pinned release lacks it):

```
indexed 714 files, 4876 blocks in 266 ms          (doc comments + markdown paragraphs,
                                                   tokenize = 'porter unicode61')
2682 candidate blocks scanned in 19129 ms; 214 pairs above 0.72   (blocks of 25–120 tokens,
                                                   12+ distinct non-stopword terms)
  1.01  cosmic/fs/find.tl:20  ~  cosmic/fs/find.tl:395
        "Convert a glob pattern to a Lua pattern. Supports * (any run) and ? (o"
```

The exact duplicates score 1.00; the interesting band is below it, and its threshold is
unknown. `_work/find.tl`'s header records what happens when a bm25 ratio is trusted
without measuring: over 914 board titles, true duplicate pairs scored 1.00, 0.62, 0.40
and 0.27 while unrelated titles' closest neighbours ranged 0.21–0.91, so no threshold
separated them and `SIMILAR_RATIO` stayed a guess. Prose blocks are longer than titles
(25–120 tokens against 8–15), which is the one reason to expect better separation here;
whether it holds is the question this item answers, and a report with a measured
threshold is worth shipping while a gate with a guessed one is not.

The 19 s scan is one query per candidate block (2682 queries, ~7 ms each, most of it
the 30–80-term OR expression). A per-file scope (`--make run _tool/prose_similar.tl
cosmic/fs`) is proportionally cheaper; the whole-tree pass is a report a session runs
on purpose, never a gate stage.

## Change

Research with one shippable outcome; deliverable is a `--result` handover with the
measurements below and the follow-up item(s).

1. **Fixture.** `_tool/testdata/prose_pairs.tl`, a literal table (`cosmic.literal`)
   of hand-labelled pairs from the tree at a named sha: at least 10 TRUE near-duplicates
   (start from the 19 exact groups the sibling item lists, before that item cleans them,
   plus re-worded copies found by reading the 214 pairs above 0.72 — paste the ones
   kept) and at least 20 CONTROLS: blocks whose top hit is topically related and not a
   copy (two functions in one module documenting adjacent behaviour). Every later
   signal is scored on this set.
2. **Signal A, bm25 self-ratio** as prototyped: OR-query of the block's distinct
   terms (stopwords dropped, 3+ characters), `bm25()` of the best other hit over the
   block's own score. Score the fixture; paste every pair's ratio and every control's
   closest-other ratio.
3. **Signal B, token-set Jaccard** over the same `porter unicode61` tokens, read back
   from an `fts5vocab` instance-level table so nothing new is tokenized. Same scoring.
4. **Decision rule, stated before measuring:** a signal ships when every true pair
   scores above every control by a margin of at least 0.10. If A or B passes, the
   follow-up is one item: `_tool/prose_similar.tl` (a `--make run` report: `path:line ~
   path:line  ratio` per pair above the measured threshold, symmetric pairs collapsed,
   scope narrowed by paths) with `_tool/prose_similar_test.tl` holding the margin on the
   fixture. It stays a report — a session runs it before a docs sweep and decides — and
   never a gate, because a near-duplicate has a legitimate form (two modules restating
   one contract in their own words) the exact gate cannot mistake but a threshold can.
5. If neither passes: record the spreads and end the line here; the exact gate is the
   whole enforcement, and the report is not built on a signal that does not separate.

Ready when: `o/bin/cosmic -e 'local db=assert(require("cosmic.sqlite").open(":memory:"));
print(db:query_one("SELECT 1 AS ok FROM pragma_module_list WHERE name=?", {"fts5"}) and
"present" or "absent")'` prints `present` — true after `bin/cosmic --make build` at this
tree's cosmos pin; the report runs under the built binary via `--make run`, never the
pinned release.

## Non-goals

A gate. Semantic or vector similarity («Pszd_rIKz» records why not). Comment quality.
Board items (their own sweep is «va0I_6MWO»). The exact-duplicate gate, filed beside
this one, which lands regardless of this item's outcome.
