`third_party/lua/cosmo/lunix.c`:

1. **Do not use `LoadMagnums`/`MagnumStr`** — see Evidence for why it
   is the wrong mechanism for these two families. Instead, add two new
   static arrays of a plain, direct name→value struct (a shape this
   file does not have yet — introduce it once, shared by both):

   ```c
   struct NameValue { const char *name; int value; };
   ```

   `kErrnoNames[]`: one `{"E<NAME>", E<NAME>}` row per genuine errno
   entry — the STRING key keeps the full name including its leading
   `E` (corrected 2026-09-06: an earlier draft of this row said "drop
   the leading `E` from the string", directly contradicting this
   spec's own Evidence, which requires full-name keys — `unix.E` must
   answer `unix.E["ENOENT"]`, matching `DEFAULT_SIGNALS` and
   `code_of("ENOENT")`'s existing call shape); re-derive the exact 96
   from the `// errno` block, not from the naive 100-count grep —
   confirm the block's current start/end line numbers first. Because
   `E<NAME>` is a compile-time literal (not an extern symbol), this
   initializer is ordinary, portable C — no assembly, no relocation
   trick needed, unlike `MagnumStr`.

   `kSignalNames[]`: one `{"SIG<NAME>", SIG<NAME>}` row per genuine
   (non-`SIG_*`) signal entry — full name including `SIG`, same
   correction as above — same shape, the 28 entries.

2. **Leave every existing individual `LuaSetIntField(L, "E<NAME>", ...)`
   / `LuaSetIntField(L, "SIG<NAME>", ...)` call exactly as it is
   today** — no behavior change to any individual named field
   (`unix.EPERM`, `unix.SIGHUP`, etc. keep working exactly as now).
   This item is purely additive.

3. Add one small helper function that builds a Lua table from a
   `NameValue[]` array (`lua_createtable`, then one `lua_pushinteger`
   + `lua_setfield` per entry) and assigns the result as a field on
   `unix` — called once for `unix.E` from `kErrnoNames` and once for
   `unix.SIG` from `kSignalNames`, in `LuaUnix`.

`tool/net/definitions.lua`:

- Annotate `unix.E` and `unix.SIG` as `table<string, integer>` fields
  on the `unix` module table (a plain map type, not a record — the key
  set is deliberately open-ended for a caller doing a dynamic lookup).
- Check whether `test_definitions_coverage.lua`'s existing coverage
  scan discovers these two new fields automatically or needs an
  explicit addition (its current `LoadMagnums`-pattern scan, line 213,
  assumed a `LoadMagnums` call this item's Change no longer makes —
  read the scan's actual matching logic before assuming either way).

`cosmic-lua/cosmic` (once this binding reaches a pinned `cosmos`
release, per this repo's own binding-then-adopt staging — same shape
as `VHkK_aA5k`'s sibling item; this half is deliberately NOT scoped
into this item, only named here so the sibling item that eventually
lands it can be filed accurately):

- `cosmic/errno.tl:52`: replace `(unix as {string: any})[name] as
  integer -- cast: dynamic E* lookup, from any` with `unix.E[name]`.
- `cosmic/errno.tl:113-124`: `ERRNO_NAMES` and the hand-built `codes`
  table become redundant once `unix.E` exists — replace `local codes:
  {string: integer} = {}` plus its population loop with `local codes =
  unix.E` (or a shallow copy, if `errno.codes` must own its own table
  rather than alias the binding's) and delete `ERRNO_NAMES` (line 93)
  if nothing else in the file uses it.
- `cosmic/quicksand/proc.tl:270-273`: replace `local by_name = unix as
  {string: any} -- cast: constant lookup by name` and the loop's `local
  n = by_name[s] as integer -- cast: from any` with a direct `local n =
  unix.SIG[s]` — both casts close together, `by_name` is no longer
  needed as a separate alias.
- Regenerate/reconcile per this repo's standard cast-closing procedure
  and gate with `bin/cosmic --make ci`.

Gate the cosmopolitan half with `make -j$(nproc) o//tool/lua/test`.
