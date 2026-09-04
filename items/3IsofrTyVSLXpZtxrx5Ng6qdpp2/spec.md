## Evidence

`gitboard new` warns about a near-duplicate through `_work/find.tl`'s
`similar`: an FTS5 `bm25()` ratio over TITLES only, threshold
`SIMILAR_RATIO = 0.5`. Measured against the production board (914 items, the
procedure in find.tl's header, 2026-09-04): four known duplicate/overlap
pairs score 1.00, 0.62, 0.40 and 0.27 against their true match; twenty
unrelated titles score 0.21–0.91 (mean 0.57) against their own closest
other title. The spreads overlap over their entire range, so no threshold on
this signal separates a duplicate from a topically related item — the
warning today is noise for roughly as many `new` calls as it is signal.
Two facts bound the fix: `--make ci` runs inside a loopback-only network
namespace, so nothing at test time may call out; and the cache
(`o/board.db`) is derived and rebuildable from git alone, so anything stored
there must be recomputable offline or degrade cleanly when absent.

## Change

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

## Non-goals

Semantic search for `find` (lexical FTS stays the `find` engine); storing
anything embedding-derived in the truth store (`refs/heads/items/*`);
auto-merging or auto-closing suspected duplicates — `new` warns, a person
decides.
