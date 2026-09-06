## Evidence

Re-verified 2026-09-06 against `origin/main`: this class
("binding constant by name" in `docs/design/cast-sites.tsv`) has FIVE
rows across three files, not the two this item originally named —

    $ awk -F'\t' '$3=="binding constant by name"' docs/design/cast-sites.tsv
    cosmic/errno.tl	52	binding constant by name
    cosmic/errno.tl	119	binding constant by name
    cosmic/quicksand/caps.tl	63	binding constant by name
    cosmic/quicksand/proc.tl	270	binding constant by name
    cosmic/quicksand/proc.tl	273	binding constant by name

Four of the five are the E*/SIG* gap this item scopes:

- `cosmic/errno.tl:52` — `(unix as {string: any})[name] as integer`
  behind `code_of(name)`, the lookup `errno.is_code` rests on.
- `cosmic/errno.tl:119` — a SECOND, previously unnoted site: `errno.tl`
  already hand-builds its own `codes: {string: integer}` table
  (`errno.codes`, lines 113-124) by iterating a hand-maintained
  `ERRNO_NAMES` constant list (line 93) and casting `(unix as
  {string: any})[name]` per entry — exactly the map `unix.E` would
  provide natively. Once `unix.E` exists, this whole loop AND
  `ERRNO_NAMES` become redundant, not just recastable.
- `cosmic/quicksand/proc.tl:270` and `:273` — TWO casts in
  `become_init`, not the one this item originally cited: line 270
  casts `unix` itself to build a `by_name: {string: any}` alias, line
  273 casts the per-lookup result. Both close together once
  `unix.SIG[s]` replaces the two-step `by_name[s]`. `proc.tl`'s
  baseline entry is already exactly 2
  (`grep -F '"cosmic/quicksand/proc.tl"' _build/casts_baseline.tl`) —
  this file goes to 0.

The fifth, `cosmic/quicksand/caps.tl:63` (`number_of(name)`, looking up
Linux `CAP_*` capability constants — also individually registered,
42 `LuaSetIntField(L, "CAP_...", ...)` calls, no `LoadMagnums`,
confirmed `grep -c 'LuaSetIntField(L, "CAP_' third_party/lua/cosmo/lunix.c`
in `cosmic-lua/cosmopolitan`), is the SAME shape but a THIRD constant
family — out of this item's scope (see Non-goals), flagged as a
same-shaped follow-up.

**Correction to this item's original premise**: the constants are
NOT registered via `LoadMagnums` — traced directly in
`third_party/lua/cosmo/lunix.c` (`cosmic-lua/cosmopolitan`).
`LoadMagnums` (line 4568) is real and used for exactly four families —
`LoadMagnums(L, kIpOptnames, "IP_")`, `kTcpOptnames`/`"TCP_"`,
`kSockOptnames`/`"SO_"`, `kClockNames`/`"CLOCK_"` (lines 4591-4594) —
none of them E* or SIG*. Errno and signal names are each registered by
one hand-written call per constant:

    $ grep -c 'LuaSetIntField(L, "E' third_party/lua/cosmo/lunix.c
    100
    $ grep -c 'LuaSetIntField(L, "SIG' third_party/lua/cosmo/lunix.c
    33

The 33 `SIG*` calls include 5 that are not signal-number lookups at
all — `SIG_BLOCK`/`SIG_UNBLOCK`/`SIG_SETMASK` (sigprocmask `how`
values) and `SIG_DFL`/`SIG_IGN` (handler-pointer sentinels, registered
via an `(intptr_t)` cast, not a manifest signal number) — leaving 28
genuine `SIGxxx` numbered-signal names
(`grep -c 'LuaSetIntField(L, "SIG[A-Z]' third_party/lua/cosmo/lunix.c`
confirms 28). `DEFAULT_SIGNALS` (`cosmic/quicksand/proc.tl:35`,
`{"SIGINT", "SIGTERM", "SIGHUP"}`) and `code_of`'s own docstring
example (`code_of("ENOENT")`) both use the FULL name including its
prefix — `unix.E`/`unix.SIG` must key by full name (`"ENOENT"`,
`"SIGTERM"`), not the bare suffix `LoadMagnums`'s prefix-argument
reconstitutes for individual fields.

Neither family has an existing `MagnumStr` table to "expose" — one
would need to be built, mirroring the `kIpOptnames`-style tables
`LoadMagnums` already reads, in `libc/fmt/magnumstrs.internal.h`'s
`struct MagnumStr` shape. The 133 individual `LuaSetIntField` calls
(100 errno + 33 signal) are the only existing enumeration; no shortcut
around re-deriving one avoids restating that list once, in a new
shape.

## Change

`third_party/lua/cosmo/lunix.c`:

1. Build two new static `const struct MagnumStr[]` tables,
   `kErrnoNames` and `kSignalNames`, from the existing individual
   calls: every `LuaSetIntField(L, "E<NAME>", E<NAME>)` (100 entries,
   `grep -n 'LuaSetIntField(L, "E' third_party/lua/cosmo/lunix.c` for
   the exact list and current line numbers) becomes one
   `{"<NAME>", E<NAME>}`-shaped `kErrnoNames` row (drop the leading
   `E` from the string, matching how existing magnum tables store the
   suffix after their prefix — `LoadMagnums`'s `pfx` argument supplies
   it back); every `LuaSetIntField(L, "SIG<NAME>", SIG<NAME>)` NOT
   matching `SIG_*` (28 entries,
   `grep -n 'LuaSetIntField(L, "SIG[A-Z]' third_party/lua/cosmo/lunix.c`)
   becomes one `kSignalNames` row the same way. Leave the 5 `SIG_*`
   calls (`SIG_BLOCK`/`SIG_UNBLOCK`/`SIG_SETMASK`/`SIG_DFL`/`SIG_IGN`)
   as individual `LuaSetIntField` calls, unchanged — they are not
   signal-number lookups and do not belong in a name→signal-number map.
2. Replace the 100 individual errno calls and 28 individual (non-`_`)
   signal calls with `LoadMagnums(L, kErrnoNames, "E");` and
   `LoadMagnums(L, kSignalNames, "SIG");` in `LuaUnix` — this preserves
   every existing `unix.EPERM`/`unix.SIGHUP`-style individual field
   exactly as today (`LoadMagnums` sets the same fields
   `LuaSetIntField` did), so no existing caller of an individual named
   constant changes behavior.
3. Add a new function (mirroring `LoadMagnums`'s loop, building a Lua
   table value instead of setting fields on `unix` directly) that
   constructs `unix.E` and `unix.SIG` as their own `{string: integer}`
   tables from the same two `MagnumStr` arrays, and assign them as
   `unix.E`/`unix.SIG` in `LuaUnix`.

`tool/net/definitions.lua`:

- Annotate `unix.E` and `unix.SIG` as `table<string, integer>` fields
  on the `unix` module table (a plain map type, not a record — the key
  set is deliberately open-ended for a caller doing a dynamic lookup).
- `test_definitions_coverage.lua`'s existing `LoadMagnums` scan
  (line 213's gmatch over `C_unix`) already discovers `LoadMagnums`
  calls by pattern — verify `kErrnoNames`/`"E"` and
  `kSignalNames`/`"SIG"` are picked up by it the same way
  `kIpOptnames`/`"IP_"` already is; if the coverage test also expects a
  per-constant doc line (as the four existing families have), extend
  it in the same shape rather than special-casing the new two.

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

## Non-goals

- Not touching `IP_`/`TCP_`/`SO_`/`CLOCK_`'s existing `LoadMagnums`
  calls or their generated types — unaffected precedent, not this
  item's scope.
- Not exposing `SIG_BLOCK`/`SIG_UNBLOCK`/`SIG_SETMASK`/`SIG_DFL`/
  `SIG_IGN` through `unix.SIG` — they are not signal numbers and stay
  individual fields exactly as today.
- Not the `cosmic-lua/cosmic` cast removal in the same PR as the
  binding change — staged separately once a release carries it,
  tracked as its own item (file when this one is ready to merge,
  mirroring `VHkK_aA5k`'s sibling item exactly).
- Not `unix.fcntl`'s cast or the `zip.open` split — separate items in
  this same census.
