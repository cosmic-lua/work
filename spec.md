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
Linux `CAP_*` capability constants), is the SAME shape but a THIRD
constant family — out of this item's scope (see Non-goals).

**Correction to this item's original premise (both halves re-verified
2026-09-06, the second by a builder attempt that stopped before
writing code — see below)**: the constants are NOT registered via
`LoadMagnums`, and `LoadMagnums`/`MagnumStr` is not a general-purpose
"name → int" mechanism a new family can just reuse.

`LoadMagnums` (`third_party/lua/cosmo/lunix.c:4568`) is real and used
for exactly four families — `LoadMagnums(L, kIpOptnames, "IP_")`,
`kTcpOptnames`/`"TCP_"`, `kSockOptnames`/`"SO_"`,
`kClockNames`/`"CLOCK_"` (lines 4591-4594) — none of them E* or SIG*.
`struct MagnumStr` (`libc/fmt/magnumstrs.internal.h`) stores each
entry's value as a byte OFFSET from the table's own base address to a
memory location holding the real int, and `MAGNUM_NUMBER` DEREFERENCES
that computed address (`*(const int *)((uintptr_t)TABLE +
TABLE[i].x)`). This only produces a correct value when the encoded
quantity is the address of a real, OS-resolved `extern int NAME;`
object (every existing `LoadMagnums` table is hand-written `.S`
assembly for exactly this reason — a link-time symbol-difference
relocation, not expressible as a portable C static initializer; GCC
rejects the equivalent `(int)((intptr_t)&a - (intptr_t)&b)` literal
with "initializer element is not constant"). Errno and signal
constants are the opposite case — `libc/errno.h` / `libc/sysv/consts/sig.h`
define them as plain, Cosmopolitan-canonicalized compile-time
`#define` literals with no backing extern symbol. Feeding a literal
through the same offset/dereference scheme computes an address equal
to the literal's own small numeric value (1, 2, 3, ...) and
dereferences it — a guaranteed SIGSEGV in the universally-unmapped low
guard-page region, on every OS this project targets, on the very
first call inside `LuaUnix()`. **`LoadMagnums`/`MagnumStr` cannot be
reused for this item's two families; a plain, direct name→value table
is the correct shape instead** (see Change).

Errno and signal names are each registered today by one hand-written
`LuaSetIntField` call per constant. The exact count needs a narrower
pattern than a bare `'LuaSetIntField(L, "E'` grep, which also matches
four unrelated termios `c_lflag` fields declared later in the file
under a `// termios c_lflag` comment (`third_party/lua/cosmo/lunix.c:5173-5176`:
`ECHO`, `ECHOE`, `ECHOK`, `ECHONL` — their names happen to start with
"E" too, but they are not errno codes):

    $ grep -c 'LuaSetIntField(L, "E' third_party/lua/cosmo/lunix.c
    100

The real, contiguous errno block is under the `// errno` header,
`third_party/lua/cosmo/lunix.c:4597-4692` — **96 genuine entries**, not
100 (confirm the current line range and count directly before
building; line numbers drift).

    $ grep -c 'LuaSetIntField(L, "SIG' third_party/lua/cosmo/lunix.c
    33

This count is accurate as originally stated: 33 `SIG*` calls include 5
that are not signal-number lookups at all — `SIG_BLOCK`/`SIG_UNBLOCK`/
`SIG_SETMASK` (sigprocmask `how` values) and `SIG_DFL`/`SIG_IGN`
(handler-pointer sentinels via an `(intptr_t)` cast, not a manifest
signal number) — leaving **28 genuine `SIGxxx` numbered-signal names**:

    $ grep -c 'LuaSetIntField(L, "SIG[A-Z]' third_party/lua/cosmo/lunix.c
    28

`DEFAULT_SIGNALS` (`cosmic/quicksand/proc.tl:35`,
`{"SIGINT", "SIGTERM", "SIGHUP"}`) and `code_of`'s own docstring
example (`code_of("ENOENT")`) both use the FULL name including its
prefix — `unix.E`/`unix.SIG` must key by full name (`"ENOENT"`,
`"SIGTERM"`), not the bare suffix.

## Change

`third_party/lua/cosmo/lunix.c`:

1. **Do not use `LoadMagnums`/`MagnumStr`** — see Evidence for why it
   is the wrong mechanism for these two families. Instead, add two new
   static arrays of a plain, direct name→value struct (a shape this
   file does not have yet — introduce it once, shared by both):

   ```c
   struct NameValue { const char *name; int value; };
   ```

   `kErrnoNames[]`: one `{"<NAME>", E<NAME>}` row per genuine errno
   entry (drop the leading `E` from the string; re-derive the exact 96
   from the `// errno` block, not from the naive 100-count grep —
   confirm the block's current start/end line numbers first). Because
   `E<NAME>` is a compile-time literal (not an extern symbol), this
   initializer is ordinary, portable C — no assembly, no relocation
   trick needed, unlike `MagnumStr`.

   `kSignalNames[]`: one `{"<NAME>", SIG<NAME>}` row per genuine (non-
   `SIG_*`) signal entry, same shape, the 28 entries.

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

## Non-goals

- Not touching `IP_`/`TCP_`/`SO_`/`CLOCK_`'s existing `LoadMagnums`
  calls or their generated types — those four families ARE the
  correct shape for `LoadMagnums` (real extern OS-resolved symbols);
  unaffected precedent, not this item's scope.
- Not exposing `SIG_BLOCK`/`SIG_UNBLOCK`/`SIG_SETMASK`/`SIG_DFL`/
  `SIG_IGN` through `unix.SIG` — they are not signal numbers and stay
  individual fields exactly as today.
- Not the `cosmic-lua/cosmic` cast removal in the same PR as the
  binding change — staged separately once a release carries it,
  tracked as its own item (file when this one is ready to merge,
  mirroring `VHkK_aA5k`'s sibling item exactly).
- Not `unix.fcntl`'s cast, the `zip.open` split, or `CAP_*`
  (`QNQK_p3Wg`) — separate items; note `QNQK_p3Wg`'s own spec still
  points at this item's ORIGINAL (`LoadMagnums`-based) Change as its
  worked template — that pointer is now wrong and needs its own
  correction when `QNQK_p3Wg` is next refined, referencing this
  item's corrected Change instead.
