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
