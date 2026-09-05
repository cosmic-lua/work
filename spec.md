## Evidence

Three small, independent, schema-free pieces from gitboard's cache/find
layer, none of which exist in `cosmic.sqlite` today (`grep -rln
"fts\|create_function\|materialized\|digest\|schema_fingerprint" cosmic/sqlite/*.tl`,
2026-09-05: only `defaults.tl`'s ordinary WAL-on-open option and its
test, nothing else):

1. **Atomic rebuild-in-place for a WAL file.** `_work/cachedb.tl`'s
   `open_conn` (WAL + `synchronous = OFF` on open) and `wipe` (remove a
   file plus its `-wal`/`-shm` sidecars), combined with `_work/cache.tl`
   `rebuild`'s temp-path handling and closing sequence: write to a
   `<final>.tmp.<pid>` path, `PRAGMA journal_mode = DELETE` to force a
   WAL checkpoint and drop the sidecars *before* closing, remove any
   leftover sidecars, `fs.move` into place, reopen WAL. The
   WAL-sidecar-before-rename step is a genuine, non-obvious gotcha
   (skip it and a rename leaves a stale `-wal` beside the new file)
   worth capturing once rather than every caller re-deriving it.
2. **Schema-fingerprint + a tiny meta-table.** `_work/cachedb.tl`'s
   `schema_fingerprint(db)` (hashes `sqlite_master`'s materialized SQL,
   not DDL source text, so it also catches things a DDL diff would
   miss — a tokenizer argument buried in an FTS5 virtual table's own
   definition) plus `meta_get`/`meta_set`/`db_user_version` — a plain
   key/value table plus `PRAGMA user_version`, the standard "does this
   file still match what I'd build fresh" check. All four take only
   `sqlite.Database` and strings.
3. **FTS5 MATCH-expression builders.** `_work/find.tl`'s `escape_token`
   (quote a token, doubling interior quotes, so stray FTS5 syntax
   characters in free-typed text — `AND`, `-`, `*`, `(`, `)`, `:`, `^`
   — read as literal text, not query syntax), `match_all` (AND-join,
   every token required), `match_any` (OR-join). Pure string functions,
   no `sqlite.Database` argument at all — they build a MATCH expression
   string, nothing more. A second, independent consumer already exists
   on the board: «So6c_e5pY» ("cosmic.doc.search: move --docs off
   substring matching onto FTS5 and bm25") will need exactly this kind
   of query-escaping once it lands — these helpers have zero FTS5-module
   dependency themselves (no `sqlite.open` call), so they're buildable
   regardless of «So6c_e5pY»'s own FTS5-in-the-pin blocker.

## Change

1. `cosmic/sqlite/extras.tl` (128 lines today, room to grow) or a new
   file if the addition crosses the line cap: port `open_conn`/`wipe`'s
   mechanism as one function (e.g. `sqlite.rebuild_atomic(final_path,
   fill_fn)` — `fill_fn` gets the fresh WAL connection to populate, the
   wrapper handles temp path, checkpoint, sidecar cleanup, rename,
   reopen).
2. Same file or a sibling: `schema_fingerprint(db)` plus minimal
   `meta_get`/`meta_set` helpers — either a tiny convention (a
   `cache_meta`-shaped table the caller opts into) or documented as "the
   pattern," whichever keeps the wrapper honest about how little
   opinion it holds about the caller's own schema.
3. Same file or a sibling: `escape_token`/`match_all`/`match_any`,
   ported verbatim — no sqlite dependency to wire up, pure string
   functions.
4. Tests: port the existing coverage for all three (the 304-style pure
   fold tests `find_test.tl`/`cachedb_test.tl` already have for the FTS
   builders and the fingerprint function; a new atomic-rebuild test —
   kill the process mid-build, or simulate a leftover `-wal`, and assert
   the final file is never half-written).
5. `cosmic --docs` entries for each.

## Non-goals

The digest-gated guard/patch/heal orchestration itself (`_work/cache.tl`
`open`/`apply_patch`/`guard`/`after_save`) — every hook that would need
to become a callback (what "digest" means, what "patch" means, what
"rebuild" means) is schema/domain-specific; forcing it into a generic
function would produce more indirection than value. The FTS5 virtual
table DDL, bm25 column weights, and ranked-row query in `find.tl` —
tuned against this board's own data, not a generic search API.
`index.tl`/`index_priority.tl` — pure board-schema SQL, no separable
mechanism.
