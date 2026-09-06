## Evidence

`cosmic/quicksand/caps.tl:63`'s `number_of(name)` casts `(unix as
{string: any})[name] as integer -- cast: dynamic constant lookup` to
resolve a Linux capability name to its number. `QNQK_p3Wg`
(cosmic-lua/cosmopolitan#392) adds `unix.CAP` as a real
`table<string, integer>` name→value lookup, closing this gap at its
source — the same staging shape as `rhKJ_HSQd`'s own `cosmic`-side
sibling item for `unix.E`/`unix.SIG`.

The new `unix.CAP` table is not usable from `cosmic-lua/cosmic` until
(a) `QNQK_p3Wg` merges, (b) a `cosmos` release exists whose tagged
commit descends from that merge, and (c) `3p/cosmos/cosmos_pin.tl` is
bumped to name it.

## Change

Ready when: `QNQK_p3Wg` is `done` (merge commit sha recorded), AND a
`cosmos` release exists descending from that commit (verify with
`git merge-base --is-ancestor <QNQK_p3Wg-merge-sha> <release-tag-sha>`
in the `cosmic-lua/cosmopolitan` checkout), AND
`3p/cosmos/cosmos_pin.tl` in `cosmic-lua/cosmic` is bumped to (or
already at) that release. Until all three hold, this item is not
resolvable.

Once ready:

- `3p/cosmos/cosmos_pin.tl`: bump to the qualifying release, if not
  already there when this is picked up.
- `cosmic/quicksand/caps.tl:63`: replace `number_of(name)`'s
  `(unix as {string: any})[name] as integer -- cast: dynamic constant
  lookup` with a direct `unix.CAP[name]` lookup against the new typed
  table; handle the not-found case per this module's existing error
  convention.
- `_build/casts_baseline.tl` / `docs/design/cast-sites.tsv` /
  `docs/design/casts.md`: regenerate and reconcile per this repo's
  standard cast-closing procedure (`bin/cosmic --make run
  _build/casts.tl --baseline`, `bin/cosmic --make run
  _build/cast_sites.tl --reconcile`), and update whichever class
  section in `casts.md` currently documents this site.
- `bin/cosmic --make ci` ends `ci: PASS` on a COLD build (`rm -rf o`
  first) — `Hkal_OAFy`'s own bounce this session found a cosmos-pin
  circularity hazard specific to `cosmic/zip.tl`; while `caps.tl` is
  not part of that same bootstrap closure (verify this directly before
  assuming it's safe), a cold-build check catches the class of bug a
  converged/incremental one can hide.

## Non-goals

Not re-litigating `unix.CAP`'s own shape — that is `QNQK_p3Wg`'s scope,
already landed by the time this item is ready.
