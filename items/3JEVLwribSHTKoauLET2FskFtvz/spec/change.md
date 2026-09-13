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
