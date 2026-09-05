## Theme

Round out `cosmic.sqlite` as a self-contained battery: the six items grouped
here each close one gap between what the vendored SQLite build already
compiles in and what the Lua wrapper actually exposes — extension loading,
FTS5, pragmas, in-memory open via deserialize, and the vector-search
question. Grouped because they share one surface (`cosmic/sqlite/**`,
`cosmo.lsqlite3`) and one register-or-fail shape decision keeps recurring
across them (extensions, FTS5 availability, vector search).

## Children

- lsqlite3: bind sqlite3_deserialize for in-memory open
- sqlite db:pragma(): the one common operation with no ergonomic, injection-safe path
- cosmic.sqlite: an extensions option on open, ensure-or-fail, empty by default
- vector search for cosmic: sqlite-vec versus sqlite.org Vec1 (capture, decision deferred)
- lsqlite3: db_register_extension rejects SQLITE_OK_LOAD_PERMANENTLY (appendvfs) as a failure
- cosmic.sqlite.fts: the two-statement full-text battery
