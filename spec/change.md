Research with one shippable outcome; deliverable is a `--result` handover with the
measurements below and the follow-up item(s).

1. **Fixture.** `_tool/testdata/prose_pairs.tl`, a literal table (`cosmic.literal`)
   of hand-labelled pairs from the tree at a named sha: at least 10 TRUE near-duplicates
   (start from the 19 exact groups the sibling item lists, before that item cleans them,
   plus re-worded copies found by reading the 214 pairs above 0.72 — paste the ones
   kept) and at least 20 CONTROLS: blocks whose top hit is topically related and not a
   copy (two functions in one module documenting adjacent behavior). Every later
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
