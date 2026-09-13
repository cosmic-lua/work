- **No `column_blob` reader.** Measured 2026-08-25 by inserting
  `sqlite.blob("\1\2\3")` and reading it back: a BLOB column arrives as a Lua
  `string`, indistinguishable from TEXT, so a blob reader would be a synonym
  for `column_text` that asserts nothing extra. Not shipped, not stubbed.
- **No nullable variant.** An absent column and a SQL NULL both read as `nil`
  off a `Row` and the readers do not distinguish them; a caller that wants a
  nullable column keeps reading `row.x` directly. Do not add a `column_*_or_nil`
  family or a fourth return slot to work around this.
- **No per-row metatable, and no change to the row's runtime shape.** The rows
  built in `cosmic/sqlite/row_iter.tl`'s `__call` are on the query hot path;
  the readers are free functions over a plain table precisely so that path is
  untouched. Do not change `Rows`' `__call`/`__close` signatures, `db:query`,
  `db:query_one`, or `stmt:rows`.
- **Do not touch the other `from any` sites under `cosmic/sqlite/`.**
  `cosmic/sqlite/bind.tl` (2) and `cosmic/sqlite/extras.tl` (4) are the
  dynamic-value-boundary class and belong to item `3IOK4SZH`;
  `cosmic/sqlite/close_test.tl` lines 62 and 179 (`mt["__close"] as
  function(any, any)`) are the same class. `close_test.tl`'s baseline row goes
  5 → 4, not to zero.
- **Do not rewrite `docs/design/casts.md`.** It is a dated census against
  `d3e59de7` and is meant to read as one; re-measuring it is separate work.
- **No new `*_example.tl` entries** and no edits to `cosmic/sqlite/init_example.tl`.
- No cast may be added anywhere in the diff, and no gate is weakened or
  exempted to make the numbers move.
