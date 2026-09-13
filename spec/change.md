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
