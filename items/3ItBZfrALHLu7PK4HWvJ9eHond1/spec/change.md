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
