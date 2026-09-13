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
