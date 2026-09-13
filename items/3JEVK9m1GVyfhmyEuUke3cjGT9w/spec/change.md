All in `/home/user/cosmopolitan`, `tool/net/lzip.c` (2179 lines total
today; this adds one appender method, no existing method's behavior
changes — comfortably under the ~400-line smell threshold).

1. Add `appender:compact() -> true | nil, error` to
   `kLuaZipAppenderMethods` (`tool/net/lzip.c:2141-2146`, alongside
   `close`/`add`/`add_file`/`remove`), implemented as
   `LuaZipAppenderCompact` near `LuaZipAppenderRemove`
   (`:1919-1961`)/`LuaZipAppenderClose` (`:1964-2075`).
2. Behavior: rewrite the LOCAL FILE DATA of every surviving entry
   (`a->existing[0..existing_count)`) into contiguous space starting at
   `a->prefix_size` (the APE-binary-prefix boundary the struct already
   tracks, `:93`), eliminating every gap left by prior `remove()` calls,
   then fall into the same central-directory-write-and-truncate logic
   `LuaZipAppenderClose` already has (`:2019-2075`) with the newly
   assigned offsets. Concretely:
   - copy `a->existing` into a scratch array and sort it by current
     `offset` ascending — `remove()`'s swap-removal
     (`:1931-1939`) does not preserve file order, and compaction MUST
     process entries in increasing original-offset order: for each
     entry, `pread` its full local-file-header-plus-data span (recover
     the header size from the entry's own `namelen`/`compsize`/
     `uncompsize` via the existing `GetLfileHdrSize`, `:940`) from its
     current `offset`, `pwrite` it at the next output cursor (which is
     always ≤ the entry's own current offset, so no entry's unread
     source bytes are ever overwritten before they are read), advance
     the cursor by the span size, and set the entry's `offset` field to
     where it was just written.
   - any `pending` entries (added but not yet flushed) are unaffected —
     they already get freshly written local data on close
     (`:1988-2017`); compaction only concerns entries that pre-date this
     appender session and still reference old on-disk offsets.
   - after compaction, set `a->data_end` to the new cursor position and
     mark the appender `dirty` (`:1958`'s flag) so `close()`'s existing
     "nothing to do" fast path (`:1973-1977`) is skipped and the central
     directory gets rewritten against the new offsets.
   - reuse `LuaZipAppenderClose`'s existing central-directory-write +
     `fsync` + `ftruncate` + `fsync` sequence (`:2019-2075`) rather than
     duplicating it — factor that block into a static helper both
     `compact()` (called mid-session) and `close()` (called at the end)
     can invoke, OR simply document that `compact()` performs the data
     rewrite only and a subsequent `close()` (already required to
     persist anything) writes the shrunk central directory — pick
     whichever keeps `LuaZipAppenderClose` itself smallest; either shape
     keeps the change inside `lzip.c`.
   - carry `LuaZipAppenderClose`'s existing non-atomicity caveat
     (`:2050-2053`) forward verbatim in `compact()`'s doc comment: this
     is an in-place rewrite, not crash-atomic; a caller wanting atomicity
     copies to a fresh path and renames into place, exactly as today.
3. Update the doc comment at `tool/net/lzip.c:1914-1918` (the one
   `remove()` carries and cosmic's `zip.d.tl` mirrors) to point at
   `compact()` as the remedy, replacing "there is no way to compact" in
   spirit — keep the existing sentence about dead space (it stays true
   between a `remove()` and the next `compact()`), add one sentence
   naming the new method.
4. `tool/net/definitions.lua`: add the `compact` method's annotation
   next to wherever `remove`'s is declared (mirror its `@return`/error
   shape — `true | nil, error`, no third slot, matching `remove`'s own
   contract) so the annotation-coverage ratchet test passes and cosmic's
   generated `zip.d.tl` picks it up in the same pin bump.
5. Tests: extend whichever `test/net/*zip*` (or equivalent) suite
   already exercises `appender:remove`'s dead-space behavior — grep for
   the existing test asserting file size is unchanged after `remove()`
   (the issue's own repro snippet is the shape to codify) — with a
   paired case: add N entries, remove some, `compact()`, `close()`, and
   assert (a) the file shrank by roughly the removed entries' on-disk
   footprint, (b) every surviving entry still reads back byte-identical
   through the reader path, (c) a directory-prefix removal
   (`remove("dir/")`) followed by `compact()` also shrinks correctly.
6. Gate: `make -j$(nproc) o//tool/lua/test`.
