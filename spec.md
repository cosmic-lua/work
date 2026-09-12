## Goal

Give `zip.appender`'s `remove()` a way to physically shrink an archive.
Today removing an entry only unlinks its central-directory record; the
local file data stays as dead space forever, and the gap between what a
strip *logically* removes and what it *physically* recovers is far
larger in practice than cosmic-lua/cosmopolitan#218's own numbers — this
item re-measures it on the current tree and finds it worse, then adds
the smallest fix the issue itself proposes: an appender `compact()`.

## Evidence

Checked out `/home/user/cosmopolitan` at `780f4505` (`origin/master`,
fetched 2026-09-12). The behavior #218 reports is unchanged, verbatim,
in the source:

```
$ grep -n -B2 -A4 'appender:remove(name)' tool/net/lzip.c
1914:// appender:remove(name) -> true | nil, error
1915:// Removes entries by name from the appender (existing or pending).
1916:// If name ends with '/', removes all entries with that directory prefix.
1917:// The local file data for removed existing entries remains as dead space
1918:// in the archive; only the central directory reference is removed.
```

`grep -n 'compact\|Compact\|rewrite\|Rewrite' tool/net/lzip.c` finds only
one hit, an unrelated safety comment on the close-time central-directory
rewrite (`:2050`, "This in-place rewrite is NOT crash-atomic") — no
compaction path exists anywhere in the 2179-line file. `LuaZipAppenderClose`
(`tool/net/lzip.c:1964-2075`) writes new pending entries starting at
`a->data_end`, rewrites the central directory after them, and truncates —
but every surviving *existing* entry keeps its original `offset`
(`tool/net/lzip.c:2025-2026`, `WriteCdirEntry(fd, &a->existing[i],
a->existing[i].offset)`), so a removed entry's local file bytes, which sit
somewhere before `data_end`, are never touched, never overwritten, and
never truncated away — `ftruncate` at `:2065` only cuts the tail after
the new central directory. This is exactly the mechanism #218 describes.

**Fresh repro, on the current tree, worse than #218's own numbers.**
Built `bin/cosmic --make build` in `/home/user/cosmic` (root
`/tmp/…/ziptest/hello`, a copy of `_make/testdata/hello`) against base
`o/bin/cosmic` (9,447,451 bytes, 809 zip entries):

```
$ unzip -l o/bin/cosmic | tail -1
  8510805                     809 files
$ bin/cosmic --make build   # strips down to hello's own artifact
$ unzip -l o/bin/hello | tail -1
   551860                     260 files
$ stat -c%s /home/user/cosmic/o/bin/cosmic o/bin/hello
9447451
9410869
```

The strip logically removes 549 of 809 entries and
8,510,805 − 551,860 = **7,958,945 bytes uncompressed** (93.5% of the
payload) — yet the artifact only shrinks by
9,447,451 − 9,410,869 = **36,582 bytes**, 0.4% of the archive and
under half a percent of the logically-removed payload. #218's own
numbers (~1.4 MB logically removed, ~14 KB physically recovered) show
the same shape at smaller scale; the gap has grown as cosmic's stripped
set has grown, not shrunk.

**No board item covers this.** `bin/gitboard find "zip compact"`,
`"zip.rewrite"`, and `"Appender:remove"` return zero hits for this
problem; the one related open item, `«ER8g_WTnv»` ("zip extract:
per-file Lua dispatch and syscalls, not zlib churn"), is about bulk
*extract* throughput and its own text treats `embed.write`'s
`appender:remove` calls (`cosmic/embed/init.tl:389,408,426`) as a given,
not as something to fix — it does not propose or touch compaction.

## Change

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

## Non-goals

- No new zip method beyond `compact()` — options 2 (`zip.rewrite`) and
  3 (exposing the raw payload offset) from the issue are NOT this item;
  `compact()` on the existing appender is "the smallest thing that
  resolves the report," per the issue's own ranking.
- No change to `remove()`'s existing semantics, including the
  documented prefix/directory-removal gotcha (a name ending in `/`
  removes everything under it) — this item does not revisit that
  behavior, only what happens to the bytes afterward.
- No crash-atomicity guarantee for `compact()` — it inherits
  `close()`'s existing non-atomic in-place rewrite caveat verbatim;
  building an atomic copy-and-rename path is a separate, larger change
  if ever wanted.
- No change to `cosmic --make build`'s strip pass itself (`cosmic/
  embed/init.tl`) to actually call `compact()` — that is a follow-up
  once the binding exists; this item is the cosmopolitan-side primitive
  only. (Filing that follow-up on the cosmic side is reasonable once
  this lands, but is out of scope here.)
- No touching `LuaZipCreate`'s writer path (`tool/net/lzip.c` around
  `:1266-1319`) — that path has no remove/compact concept; only the
  appender does.

## Access

- **cosmic-lua/cosmopolitan** (home repo): read+write — the change
  lands here (`tool/net/lzip.c`, `tool/net/definitions.lua`, its test
  file).
- **cosmic-lua/cosmic**: read-only — used only to reproduce the
  downstream strip-size gap (`_make/testdata/hello` fixture, `--make
  build`) as evidence; no cosmic-side file changes in this item's
  scope (see Non-goals — wiring `compact()` into the strip pass is a
  follow-up, not this item).
