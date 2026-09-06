## Evidence

`VHkK_aA5k` (cosmic-lua/cosmopolitan) adds `zip.reader(path, options)`
as a single-shape entry point for what `zip.open(path, "r", options)`
already does dynamically, closing the union erasure at its source.
Once it lands, `cosmic/zip.tl:222`'s `handle as zip.Reader -- cast:
from any` becomes closeable by calling `zip.reader` directly instead
of `zip.open(path, "r", ...)`.

This is the exact staging shape `AGENTS.md` and `zs1K_cWnY`/`1Lhz_38Wt`
already establish for a cosmopolitan-side binding reaching cosmic-side
code: `cosmic-lua/cosmopolitan` publishes a `cosmos.zip` release on
every push to master; `cosmic-lua/cosmic` pins it by version + sha256
in `3p/cosmos/cosmos_pin.tl`. The new `zip.reader` binding is not
usable from `cosmic-lua/cosmic` until (a) `VHkK_aA5k` merges, (b) a
`cosmos` release exists whose tagged commit descends from that merge,
and (c) `3p/cosmos/cosmos_pin.tl` is bumped to name it.

## Change

Ready when: `VHkK_aA5k` is `done` (merge commit sha recorded), AND a
`cosmos` release exists descending from that commit (verify with
`git merge-base --is-ancestor <VHkK_aA5k-merge-sha> <release-tag-sha>`
in the `cosmic-lua/cosmopolitan` checkout), AND
`3p/cosmos/cosmos_pin.tl` in `cosmic-lua/cosmic` is bumped to (or
already at) that release. Until all three hold, this item is not
resolvable.

Once ready:

- `3p/cosmos/cosmos_pin.tl`: bump to the qualifying release, if not
  already there when this is picked up.
- `cosmic/zip.tl:222`: change `handle, err = zip.open(path, "r",
  raw_opts)` / `zip.open(path, "r")` (lines 215-217) to call
  `zip.reader` instead — `zip.reader(path, raw_opts)` when `raw_opts`
  is set, `zip.reader(path)` otherwise, matching `zip.create`'s own
  call shape immediately below it (line 225). Delete the `-- cast:
  from any` comment and the `as zip.Reader` cast at line 222; `handle`
  is now already typed `zip.Reader?` directly.
- `_build/casts_baseline.tl` / `docs/design/cast-sites.tsv` /
  `docs/design/casts.md`: regenerate and reconcile per this repo's
  standard cast-closing procedure (`bin/cosmic --make run
  _build/casts.tl --baseline`, `bin/cosmic --make run
  _build/cast_sites.tl --reconcile`), and update whichever class
  section in `casts.md` currently documents this site.
- `bin/cosmic --make ci` ends `ci: PASS`.

## Non-goals

Not `unix.fcntl`'s cast (`cosmic/fd.tl:187`) — tracked separately,
pending a `cosmic.fd` API decision `VHkK_aA5k`'s sibling item raises.
Not re-litigating `zip.reader`'s own shape — that is `VHkK_aA5k`'s
scope, already landed by the time this item is ready.
