## Evidence

«J9eH_ond1» ports three primitives from gitboard's cache layer into
`cosmic.sqlite`: the atomic WAL rebuild-in-place, the schema fingerprint
with its meta table, and the FTS5 match builders. The orchestration that
uses the first two is a fourth generic piece that item leaves behind, in
`_work/cache.tl` (2026-09-05):

- `open(root, known_digest?)` (line 190): if the file exists, open it and
  compare THREE facts against what a fresh build would produce —
  `PRAGMA user_version` to a schema constant, the `schema_fingerprint`
  meta row to `expected_schema_fingerprint()`, and a `refs_digest` meta
  row to a digest of the SOURCE the cache derives from (here a
  `for-each-ref` snapshot; the caller may pass one it already took) —
  and hand back the open connection only when all three match; otherwise
  `wipe` and `rebuild`.
- `heal(root, cause)` (222): when an incremental patch of an open cache
  fails for a genuine SQLite reason, wipe and rebuild ONCE, since the
  source of truth already carries what the patch was landing; a second
  failure is returned as-is, never a retry loop.
- `guard(root, known_digest?)` (310) / `after_save` (337): take the
  source digest before a write, patch after it only if the file still
  records that digest, otherwise leave it for the next `open` to rebuild.

Every derived SQLite cache over an external source (a directory tree, a
git ref namespace, an API's ETag set) needs exactly this: "is this file
still what I would build fresh, and if not, rebuild it atomically; if a
patch goes wrong, rebuild once rather than trust a half-applied file."
Fifty lines, but the three-way check (version, fingerprint, digest) and
the rebuild-once rule are the parts a second implementer gets subtly
wrong.

## Change

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

## Non-goals

The incremental patch CONTENT (what rows a save touches is the caller's);
the FTS layer; gitboard's own port onto this (a follow-up after a release
carries it).
