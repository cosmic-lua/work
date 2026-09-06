## Evidence

`definitions.lua` is more honest than the generated types can carry:
bindings whose return shape depends on a LITERAL argument are
annotated with exact `@overload` lines that `gentype` erases to a
union, and the erasure is where a from-any cast comes from downstream
in `cosmic-lua/cosmic`. Originally measured 2026-08-26 against two call
sites (`zip.open`, `unix.fcntl`); re-verified 2026-09-06 against
`origin/master` (`b9246f8d`) — one of the two has since resolved itself
by accident, the other still stands:

- **`zip.writer`/`zip.appender` already exist** (`tool/net/definitions.lua`
  `zip.create`/`zip.append`, both landed 2026-09-02 by `f5dd671a`, an
  unrelated sqlite3 commit that also touched zip in passing — confirmed
  via `git log -S'function zip.create' -- tool/net/definitions.lua`).
  Both are already single-shape, non-union entry points
  (`zip.create(path, options): zip.Writer?, string?`,
  `zip.append(path, options): zip.Appender?, string?`), and
  `cosmic/zip.tl`'s "write"/"append" branches (lines 224-239) already
  call them directly with no cast. Two of this item's original three
  splits are done, by a change unrelated to this item.
- **`zip.open`'s "r" (read/default) mode still erases to a union.**
  `tool/net/definitions.lua`'s current `@overload` block (now at
  line ~1985, drifted from the original 1859-1861) still gives `zip.open`
  one exact overload per mode; `cosmic/zip.tl:222` still casts
  `handle as zip.Reader` after calling `zip.open(path, "r", raw_opts)`
  (`grep -n 'handle as zip.Reader' cosmic/zip.tl` confirms, same line
  today).
- **The C-level split is nearly free**: `tool/net/lzip.c`'s `LuaZipOpen`
  (line 2153) is a thin dispatcher — for mode `"r"` it calls
  `return LuaZipOpenReader(L);` directly, after shifting the mode
  argument off the stack, so `LuaZipOpenReader` (line 246) ALREADY
  takes exactly `(path: string|integer, options?: table)` — the same
  argument shape `LuaZipCreate`/`LuaZipAppend` already expose as
  `zip.create`/`zip.append`. It is a static function today, registered
  nowhere in `kLuaZip[]` (`tool/net/lzip.c:2190`, currently `open`,
  `from`, `create`, `append`, `validate_name`) — adding one entry
  exposes it with zero new C logic.
- **`unix.fcntl`'s per-cmd unions are unchanged and out of scope here**
  (see Non-goals) — `cosmic/fd.tl:187`'s cast still stands, but closing
  it is not a binding-split problem: `handle:fcntl(cmd, value)` is
  `cosmic.fd`'s own DELIBERATELY generic escape hatch (its only call
  site, confirmed via `grep -rn 'unix.fcntl' cosmic/*.tl` in
  `cosmic-lua/cosmic` — no other file calls it), accepting any runtime
  `cmd`. A cosmopolitan-side split alone has nowhere to plug in without
  `cosmic.fd` first deciding whether to add typed per-cmd accessor
  methods alongside (or instead of) the generic one — an API decision
  for `cosmic-lua/cosmic`, not a fact this item's own evidence settles.

## Change

`tool/net/lzip.c`:
- `kLuaZip[]` (line 2190): add `{"reader", LuaZipOpenReader}` alongside
  the existing `open`/`from`/`create`/`append`/`validate_name` entries.
  No change to `LuaZipOpenReader` itself — it already has the right
  signature and behavior.

`tool/net/definitions.lua`:
- Add a `zip.reader` annotation immediately after `zip.open`'s block,
  mirroring `zip.create`'s existing shape exactly:

  ```
  --- Opens a ZIP archive for reading. This is equivalent to
  --- `zip.open(path, "r", options)`.
  ---@param path string|integer Path to the ZIP file, or file descriptor
  ---@param options? zip.OpenOptions Optional settings
  ---@return zip.Reader? reader ZIP reader object on success
  ---@return string? error Error message on failure
  ---@nodiscard
  function zip.reader(path, options) end
  ```

- `test_definitions_coverage.lua`'s existing `add("zip.", C_zip,
  "kLuaZip")` (line 1362) auto-discovers every `kLuaZip[]` entry and
  requires an annotation — no new test wiring needed, the ratchet
  already covers this the moment `reader` is registered.

Gate with `make -j$(nproc) o//tool/lua/test`.

## Non-goals

- Not `zip.writer`/`zip.appender` — already landed, untouched here.
- Not `unix.fcntl`'s per-cmd split — that needs a `cosmic.fd` API
  decision this item's evidence does not make (typed accessors vs. the
  existing generic escape hatch); tracked as a separate item.
- Not removing `cosmic/zip.tl:222`'s cast — that is
  `cosmic-lua/cosmic`'s side, and per this repo's own staging rule (a
  `cosmic-lua/cosmopolitan` binding reaches `cosmic-lua/cosmic` only
  once a `cosmos` release carries it and `3p/cosmos/cosmos_pin.tl` is
  bumped), it cannot land in the same PR as this one. Tracked as a
  separate, blocked sibling item.
- Not touching `zip.open` itself, its dispatch logic, or its own
  `@overload` annotations — `zip.reader` is purely additive.
