Blocked on «J9eH_ond1» (the primitives it composes).

1. `cosmic/sqlite/derived.tl`: `open(path, spec) -> Database | nil, string`
   where `spec` is `{version: integer, schema: string (DDL), digest:
   function(): string | nil, build: function(db: Database): boolean,
   string, known_digest?: string}`; on a match returns the connection, on
   a mismatch runs `build` into a temp file through «J9eH_ond1»'s atomic
   rebuild and records version/fingerprint/digest in the meta table.
2. `patch(path, spec, before_digest, fn)`: run `fn` in one transaction
   only when the file still records `before_digest`, else no-op; on a
   SQLite failure inside `fn`, rebuild once (`heal`) and return that
   outcome.
3. Tests: a fixture whose "source" is a directory of files with a digest
   over their names and mtimes — stale digest rebuilds, changed DDL
   rebuilds (fingerprint), bumped version rebuilds, matching all three
   opens without rebuilding (assert `build` is not called), a failing
   patch rebuilds exactly once.
4. A `cosmic --docs guide` snippet showing the pattern end to end.
