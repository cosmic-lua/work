## Evidence

`cosmic/quicksand/caps.tl:63`'s `number_of(name)` casts `(unix as
{string: any})[name] as integer -- cast: dynamic constant lookup` to
resolve a Linux capability name (`CAP_NET_ADMIN`, etc.) to its number
— same class as `rhKJ_HSQd`'s E*/SIG* gap ("binding constant by name",
`docs/design/cast-sites.tsv:52` row for this site), found while
tracing that item's own registration mechanism.

`CAP_*` constants are registered the same way E*/SIG* are — individual
hand-written calls, not `LoadMagnums`:

    $ grep -c 'LuaSetIntField(L, "CAP_' third_party/lua/cosmo/lunix.c
    42

in `cosmic-lua/cosmopolitan`'s `third_party/lua/cosmo/lunix.c`. No
`kCapNames`-style `MagnumStr` table exists.

**Correction (2026-09-06, orchestrator, before this item was ever
pulled): this item's original Change pointed at `rhKJ_HSQd`'s
ORIGINAL, `LoadMagnums`/`MagnumStr`-based approach as its worked
template. `rhKJ_HSQd`'s own re-verification found that approach
unusable and replaced it before building anything**: `LoadMagnums`'s
`MagnumStr` table stores each entry as a byte OFFSET from the table's
base address to a memory location holding the real int, and
`MAGNUM_NUMBER` DEREFERENCES that computed address — correct only when
the encoded quantity is the address of a real, OS-resolved `extern int
NAME;` object (every existing `LoadMagnums` table is hand-written
`.S` assembly for exactly this reason). `CAP_*`, like `E*`/`SIG*`, is a
plain compile-time `#define` literal with no backing extern symbol —
feeding one through `MAGNUM_NUMBER` computes an address equal to the
literal's own small numeric value and dereferences it, a guaranteed
SIGSEGV in the unmapped low guard page. `rhKJ_HSQd`'s corrected Change
instead adds a plain `struct NameValue { const char *name; int value; }`
array per family, built with ordinary C initializers (no assembly, no
relocation trick), and a small helper that turns one into a Lua table
field on `unix`. The same shape applies here.

## Change

Ready when: `rhKJ_HSQd` is `done` (merge commit sha recorded) — verify
with `gitboard show rhKJ_HSQd`, or in the `cosmic-lua/cosmopolitan`
checkout, that its merge commit is an ancestor of `origin/master`.
Until then this item is not resolvable; a puller that reaches it
before then drops the claim bare (item is fine as written).

Once ready, in `third_party/lua/cosmo/lunix.c`:

- Reuse the `struct NameValue { const char *name; int value; }` shape
  and the table-building helper `rhKJ_HSQd` introduces (do not
  reintroduce `LoadMagnums`/`MagnumStr` — see Evidence for why it
  cannot represent these constants). Add a third static array,
  `kCapNames[]`, with one `{"<NAME>", CAP_<NAME>}` row per genuine
  `CAP_*` entry. Re-derive the exact count and line range from the
  `// capabilities` block directly before writing the table — the
  naive `grep -c 'LuaSetIntField(L, "CAP_'` count (42, above) needs the
  same double-check `rhKJ_HSQd` had to do for `SIG*` (it found 5 of 33
  `SIG*`-prefixed matches were not signal numbers); confirm every
  `CAP_` match in this file is a genuine capability constant before
  trusting the bare count.
- Leave every existing individual `LuaSetIntField(L, "CAP_<NAME>", ...)`
  call exactly as it is today — purely additive, no behavior change to
  `unix.CAP_NET_ADMIN` etc.
- Call the shared helper once more, for `unix.CAP` from `kCapNames`, in
  `LuaUnix`.

In `tool/net/definitions.lua`: annotate `unix.CAP` as
`table<string, integer>`, matching `unix.E`/`unix.SIG`'s annotation
shape. Check whether `test_definitions_coverage.lua`'s coverage scan
picks up the new field the same way it does (or doesn't) for
`unix.E`/`unix.SIG` — read `rhKJ_HSQd`'s merged PR for how it resolved
this, rather than re-deriving it.

Gate with `make -j$(nproc) o//tool/lua/test`.

Closing `cosmic/quicksand/caps.tl:63`'s cast in `cosmic-lua/cosmic` is
its own staged item once a `cosmos` release carries `unix.CAP` and
`cosmic-lua/cosmic`'s pin is bumped to it — same staging shape as
`rhKJ_HSQd`'s own `cosmic`-side sibling item — not scoped into this
item; file it when this item is ready to merge.

## Non-goals

- Not `rhKJ_HSQd`'s own E*/SIG* scope, and not the `cosmic-lua/cosmic`
  cast removal in the same PR as the binding change (staged
  separately, see above).
- Not re-litigating whether `CAP_*` needs a typed surface at all —
  settled by this item's own Evidence, the same shape as `rhKJ_HSQd`.
