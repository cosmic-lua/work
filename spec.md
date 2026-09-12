## Goal

Carries forward cosmic-lua/cosmic#1077's real, still-open substance: `cosmic.stream`
("the contract every producer and consumer composes over") cannot be adopted by
`compress`/`tar`/`zip` — the modules that move the most bytes — because the
underlying C bindings in cosmic-lua/cosmopolitan are one-shot (whole buffer in,
whole buffer out). This slice is the enabling half only: add an incremental
deflate/inflate handle to cosmic-lua/cosmopolitan so a cosmic-side
`compress.new_reader`/`new_writer` can wrap a bounded chunk size instead of
buffering a whole archive member in memory. Serves the "efficiency" promise
(`docs/goals.md`) by removing a peak-allocation cost that is structural, not
incidental — `tar.extract` materializes an entire tarball twice in memory today
(see Evidence) purely because there is no incremental handle to stream through.

## Evidence

Verified against the C directly, on cosmic-lua/cosmopolitan `origin/master`
(`780f45055acd52401de6c95c16365338690e19e7`, fetched 2026-09-12), not inferred
from `definitions.lua` annotations alone:

```
$ grep -n "^int LuaDeflate\|^int LuaInflate" tool/net/lfuncs.c
1189:int LuaDeflate(lua_State *L) {
1248:int LuaInflate(lua_State *L) {
```

`LuaDeflate` (`tool/net/lfuncs.c:1189-1234`) takes the whole input as one
`luaL_checklstring`, calls `deflateInit2`, one `deflate(&zs, Z_FINISH)`, then
`deflateEnd` — the `z_stream` is created and destroyed inside a single call,
never returned to Lua. `LuaInflate` (`tool/net/lfuncs.c:1248-`) is the same
shape: one `inflateInit2`/loop-until-`Z_STREAM_END`/`inflateEnd` per call, no
handle escapes the C function. Neither binding has a companion
"feed one more chunk" entry point, confirming issue #1077's blocker is still
accurate today, not stale.

Independently, the zip-extraction performance research already done on this
question (board item `ER8g_WTnv`, 2026-08-23) measured a full
`inflateInit2`+`inflate`+`inflateEnd` round trip at 0.27µs and found
"`inflateReset2` stream reuse is valid... but not valuable" for the *within-one-call*
per-entry case it was scoped to — that finding is about CPU cost of repeated
one-shot calls, not about the peak-memory cost of holding a whole decompressed
buffer this issue is about; it does not contradict or supersede #1077.

The consuming cosmic-side gap, confirmed still present in `cosmic-lua/cosmic`
`main` (`c9cdb84`, fetched 2026-09-12):

```
$ grep -n "stream\.Reader\|stream\.Writer\|new_reader\|new_writer" cosmic/zip.tl cosmic/tar.tl cosmic/compress.tl
(no output)
```

`cosmic/tar.tl:191-206` (`extract`) reads the whole archive into one string
(`fs.read(archive)`), then — when gzip-encoded — passes that whole string to
`compress.decompress` (a one-shot wrapper over `cosmo.Inflate`) and holds the
whole decompressed result too:

```
191  local function extract(archive: string, destdir: string,
192      opts?: ExtractOptions): boolean, string
193    local raw, read_err = fs.read(archive)
...
197    local data = raw
198    if raw:sub(1, 2) == "\31\139" then -- gzip magic
199      local cap = (opts and opts.max_archive_bytes) or MAX_TAR
200      local inflated, gz_err = compress.decompress(raw,
201        {format = "gzip", max_output_bytes = cap})
...
205      data = inflated
206    end
```

Both `raw` and `inflated`/`data` are live in memory at once — the exact
"materializing tarballs twice" cost #1077 names.

## Change

In `cosmic-lua/cosmopolitan` (`tool/net/lfuncs.c`, plus `tool/net/definitions.lua`
in the same commit per this repo's own binding-contract convention):

1. Add two new userdata-backed entry points under `cosmo`:
   - `cosmo.Deflater(opts?)` → `deflater:userdata, nil` or `nil, error:string`.
     `opts` accepts the same `level`/`format` fields `LuaDeflate` already parses
     (reuse the existing `GetZlibFormat` helper at `tool/net/lfuncs.c:1157-1179`
     rather than duplicating its option parsing). Internally calls
     `deflateInit2` once and stores the `z_stream` in the userdata, released by
     a `__gc` metamethod (mirroring how `zip.Reader` already keeps a live C
     handle across calls — see `struct LuaZipReader` in `tool/net/lzip.c`).
   - `deflater:feed(chunk: string): string?, string` — calls `deflate(&zs,
     Z_NO_FLUSH)` against the stored stream, growing a `luaL_Buffer` until
     `avail_out` stops shrinking, and returns whatever compressed bytes are
     ready (possibly `""`/none yet — zlib may buffer internally).
   - `deflater:finish(): string?, string` — calls `deflate(&zs, Z_FINISH)` to
     flush the tail, then `deflateEnd`; a second `finish()` or a `feed()` after
     `finish()` returns `nil, "deflater is finished"`.
   - The inflate side (`cosmo.Inflater(opts?)` / `:feed(chunk)` / `:finish()`)
     is the mirror, adapting `LuaInflate`'s existing loop
     (`tool/net/lfuncs.c:1248-`) to run one `inflate(&zs, Z_NO_FLUSH)` per
     `feed` call instead of looping to `Z_STREAM_END` internally; the existing
     `maxsize` option still caps total output across all `feed`/`finish` calls
     combined (running total kept in the userdata, checked exactly where
     `LuaInflate`'s loop checks it today).
2. Follow this repo's own binding-contract rule (`AGENTS.md`): a degenerate
   input (e.g. `feed(nil)`) raises via `luaL_argerror`; a runtime failure
   (corrupt stream, `maxsize` exceeded) returns `nil, error:string` in slot 2,
   nothing in slot 3 (no syscall in play, so no `errno`).
3. Add binding tests to whatever `tool/net/*_test.lua` (or equivalent) already
   exercises `LuaDeflate`/`LuaInflate`, covering: round-trip via `feed`+`finish`
   matches a one-shot `Deflate`/`Inflate` byte-for-byte; `finish()` after
   `finish()` errors cleanly; a multi-`feed` inflate respects `maxsize` summed
   across calls, not reset per call.
4. Document the new entries in `tool/net/definitions.lua` in the same commit
   (this repo's own coverage ratchet fails a binding that loses its
   `@param`/`@return` annotations).

## Non-goals

- **The chunked zip entry reader** (`Archive:open_entry(name): stream.Reader`,
  #1077's other named blocker) is a separate, independent binding change
  (`zip.Reader:read`, `tool/net/lzip.c:672`, would need an offset/length or
  streaming variant of `ReaderSlurpEntry`) with its own design questions
  (does it hold the whole compressed member and stream only the *decompressed*
  side, or seek within the compressed data too?). Not sized into this slice;
  a natural follow-up once this lands, and it can reuse this slice's
  `Inflater` internally rather than inventing a second incremental-inflate path.
- **The cosmic-side `stream.Reader`/`stream.Writer` adoption** in
  `cosmic/compress.tl`, `cosmic/tar.tl`, `cosmic/zip.tl` (`compress.new_reader`/
  `new_writer`, `tar.extract(archive: Archive | string, ...)`) stays blocked
  until this binding lands and a `3p/cosmos` pin bump brings it into
  `cosmic-lua/cosmic`. Do not start that half yet — the pin/type-regen
  sequencing (`bin/cosmic --make fetch && bin/cosmic --make ci`) is its own
  change, not a byproduct of this one, per this repo's own "binding contract
  change... landed as its own change, never inside an optimization" rule.
- **`_make/extract.tl`'s zip-vs-tar asymmetry** (9 lines to open/extract/close
  a zip reader vs. 1 line for `untar.extract`, `_make/extract.tl:123-139`) is a
  real, separate, purely cosmic-side follow-up once `tar.extract` accepts the
  same `Archive | string` shape zip already exposes; it needs no cosmopolitan
  change and is not this slice.
- No change to `LuaDeflate`/`LuaInflate`'s existing one-shot signatures or
  return shapes — they stay as they are, used by the many cosmic callers that
  have no need for incremental behavior.

## Access

- `cosmic-lua/cosmopolitan` — read+write (home repo for this slice).
- `cosmic-lua/cosmic` — read-only (evidence for the consuming gap this
  enables; no cosmic-side edit in this slice).
