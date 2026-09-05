## Goal

`_work/find.tl`'s `similar` (FTS5 `bm25()` over titles, `SIMILAR_RATIO
= 0.5`) does not separate a real duplicate from a topically related
item — neither does either offline alternative measured in
3IsofrTyVSLXpZtxrx5Ng6qdpp2 (TF-IDF over title+spec, hashed
character-3-gram of the title; both margins decisively negative on a
verified 4-pair/20-control fixture). Ship a remote embedding signal,
cached, with a clean offline fallback, so `gitboard new` gets a
similarity check that actually separates duplicates from lookalikes
without ever requiring network access at test time or in a fenced
session.

## Evidence

3IsofrTyVSLXpZtxrx5Ng6qdpp2's measurement (2026-09-05, 959-item
production board): the identical-title pair scores 1.00/1.00/0.92
trivially under every signal tried so far; every differently-phrased
duplicate pair scores 0.57–0.63 under TF-IDF and hashed trigrams alike,
while unrelated-but-templated control pairs (sequential migration
batches, sibling pin-bump releases, parallel census slices) routinely
score 0.86–0.93 under the same signals — the discriminator is meaning,
not shared tokens/shingles, which only a semantic embedding reaches.
`grep -n load_extension` against a `cosmic-lua/cosmic` checkout's
`o/_types/types_gen/cosmo/lsqlite3.d.tl` (built via `bin/cosmic --make
build` — that generator only runs for a project defining `cosmic/**`,
which `cosmic-lua/work` itself does not, confirmed independently by two
sessions hitting "No such file or directory" from a bare `work` clone;
the equivalent probe from `work` itself is extracting
`.types/cosmo/lsqlite3.d.tl` from the pinned binary's own zip) returns
nothing, and the only extension surface is a fixed, statically-linked
registry with no vector/ANN member — sqlite-vec (or any loadable vector
extension) is unavailable; brute-force cosine in Teal is the only path. `--make ci` runs inside a loopback-only network
namespace (no outbound calls at test time), and `o/board.db` is a
derived, rebuildable-from-git cache — anything embedding-derived stored
there must degrade cleanly when absent, never block a rebuild.

## Change

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

## Non-goals

Semantic search for `find` (lexical FTS stays the `find` engine);
storing anything embedding-derived in the truth store
(`refs/heads/items/*` — `vectors` lives only in the derived
`o/board.db` cache); auto-merging or auto-closing suspected duplicates;
choosing or hard-coding a specific embedding provider/model in this
spec — that is an implementation decision the builder records against
whatever `GITBOARD_EMBED_MODEL` names, not fixed here.

## Acceptance

- `_work/testdata/similar_pairs.tl` exists, holds the 4 pairs + 20
  controls above with fresh title/spec text, and is read successfully
  by `cosmic.literal`.
- `_work/cachedb.tl`'s `SCHEMA_VERSION` is bumped and the `vectors`
  table exists with exactly the schema above.
- `similar` uses the cosine-over-`vectors` signal when rows are
  present and falls back to the current bm25 path when any needed row
  is missing — covered by a test for each branch.
- `_work/find_test.tl` asserts the 0.10 margin from
  3IsofrTyVSLXpZtxrx5Ng6qdpp2's decision rule holds on the fixture
  under the new signal.
- No API key or endpoint literal appears in the tree — both come from
  the environment, and their absence is a covered, non-fatal fallback
  path, not an error.
- `bin/cosmic --make ci` passes with no network reachable (the
  loopback-only fence), proving the fallback path is real, not merely
  documented.
