Research with one shippable outcome: find a similarity signal that
separates the known pairs from the controls with margin, and either ship it
as `similar`'s engine or record why none is available offline and what a
remote embedding stage would cost. Deliverable: a `--result` handover with
the measurements below and the follow-up item(s).

1. Fixture. Reproduce find.tl's measurement and record the ids of the four
   pairs and the twenty controls in `_work/testdata/similar_pairs.tl` (a
   literal table, read by `cosmic.literal`), so every later signal is scored
   on the same set and a test can hold the margin.
2. Signal A, offline: TF-IDF over title AND spec (the header's measurement
   was title-only), cosine similarity, vectors built from the `search` FTS
   table's tokens (`porter unicode61`, same tokenizer) so nothing new is
   parsed. Score the fixture; paste best-match and closest-control numbers.
3. Signal B, offline: hashed character 3-gram vectors of the title (a fixed
   `dim` of 512, FNV-hashed), cosine. Same scoring.
4. Decision rule, stated before measuring: a signal ships if every pair's
   true-match score exceeds every control's closest-other score by at least
   0.10. If A or B passes, the follow-up is one item: `similar` computes
   that signal over the cache connection, `SIMILAR_RATIO` and the bm25 path
   go, and `_work/find_test.tl` asserts the margin on the fixture. Vectors
   are not stored: 914 items × 512 floats is recomputed in well under the
   `new` verb's current 0.2 s.
5. If neither passes: record the gap and spec the remote stage as a
   follow-up with these decisions already made — vectors live in the cache
   as `vectors(id TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
   model TEXT NOT NULL, content_sha TEXT NOT NULL, vec BLOB NOT NULL)
   STRICT, WITHOUT ROWID`, keyed by the sha of title+spec so a rebuild
   re-embeds only what changed; brute-force cosine in Teal (no sqlite-vec —
   the pinned cosmic's sqlite is statically linked, and
   `grep -n load_extension o/_types/types_gen/cosmo/lsqlite3.d.tl` says
   whether an extension could even load); `similar` falls back to the
   offline signal when a row is missing, so `--make ci` and a fenced
   session never need the network; the API and its key come from the
   environment, never the tree.
