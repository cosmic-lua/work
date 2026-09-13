1. Fixture: create `_work/testdata/similar_pairs.tl` (literal table,
   read by `cosmic.literal`; `_work/testdata/**` is lint's one exempt
   kind, so file length is not a concern here) holding the 4 pairs and
   20 controls identified in 3IsofrTyVSLXpZtxrx5Ng6qdpp2's `## Result`:
   for each of the 28 ids, its `id`, `title`, and full `spec` body,
   fetched fresh via `store.list`/`store.read_specs` over exactly
   those ids so the embedded text is byte-identical to the live items
   at generation time. Shape:
   ```
   return {
     pairs = {
       {a = {id = "...", title = "...", spec = "..."},
        b = {id = "...", title = "...", spec = "..."}},
       -- x4
     },
     controls = {
       {id = "...", title = "...", spec = "..."},
       -- x20
     },
   }
   ```
2. Cache schema: add to `_work/cachedb.tl` (bump `SCHEMA_VERSION`, same
   pattern as `37c006ca`'s FTS DDL change) —
   ```sql
   CREATE TABLE vectors(
     id TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
     model TEXT NOT NULL,
     content_sha TEXT NOT NULL,
     vec BLOB NOT NULL
   ) STRICT, WITHOUT ROWID
   ```
   keyed by the sha256 of `title .. "\n" .. spec` so a rebuild
   re-embeds only items whose title or spec actually changed.
3. Embedding call: a new `_work/embed.tl` wrapping one HTTP call via
   `cosmic.fetch` to an embeddings endpoint. The API base URL, model
   name, and API key come from the environment (e.g.
   `GITBOARD_EMBED_API_KEY`, `GITBOARD_EMBED_MODEL`) — never
   hard-coded or read from a tracked file — so a fenced session with
   none of them set simply has no vectors to compute and every call
   degrades to the offline path (see step 5). Batch requests (one call
   per rebuild batch, not per item) to keep a full-board backfill's
   wall time and cost bounded.
4. `similar`'s engine: for a candidate title, embed it (network,
   step 3), then brute-force cosine in Teal against every row in
   `vectors` (959 rows x embedding-dim floats is a linear scan, no
   sqlite-vec — extension loading confirmed unavailable). Keep
   `SIMILAR_LIMIT`; replace `SIMILAR_RATIO`'s bm25 computation with
   this cosine score, re-deriving a ratio-to-best-hit the same way
   `similar` does today, OR (state the actual choice made during
   implementation, whichever the measured margin supports) a fixed
   cosine threshold — pick whichever the fixture's margin actually
   supports and record the number, the same way this item's own
   research recorded its.
5. Offline fallback: when the candidate has no committable vector yet,
   or ANY row `similar` needs is missing from `vectors` (no
   `GITBOARD_EMBED_API_KEY` set, a fenced session, a rebuild that
   hasn't backfilled yet), `similar` falls back to the current
   `SIMILAR_RATIO`/bm25 path unconditionally — never fails, never
   blocks `new`, never needs network at test time.
6. `_work/find_test.tl`: a new test loading
   `_work/testdata/similar_pairs.tl` and asserting the decision rule
   from 3IsofrTyVSLXpZtxrx5Ng6qdpp2's Change step 4 (every pair's
   true-match cosine exceeds every control's closest-other cosine by
   at least 0.10) — this test necessarily runs against
   pre-computed/fixture-embedded vectors (no live network call inside
   `--make ci`'s loopback fence), so the fixture must carry the actual
   embedding vectors too (extend the fixture's schema with a `vec`
   field per item, computed once outside CI and committed alongside
   the fixture) or the test is skipped/marked network-required and
   excluded from the gated `ci` lane — decide and record which,
   consistent with `--make ci`'s no-network rule.
