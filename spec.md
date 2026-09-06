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

**Bounce, 2026-09-06 — a fourth precondition, found by building, not
guessed:** (a)-(c) above all held (verified: `VHkK_aA5k` merged as
cosmic-lua/cosmopolitan#389, commit `77a16357c44e4ee5332ebbd409e08980b91affc7`;
release `2026.09.06-bee599a73` descends from it, confirmed with
`git merge-base --is-ancestor 77a16357c44e4ee5332ebbd409e08980b91affc7
bee599a73b036ed6005196faff0131a6ab1b5ae6`, exit 0; the pin was bumped
to that release as part of this attempt), but the `## Change` as
written does not survive a cold build — a structural circular
dependency, not a mistake in this item's Change:

`_types/gentype_defs.tl` (which generates `cosmo/zip.d.tl`, the type
declaration `zip.reader` needs to type-check) itself `require`s
`cosmic.zip` and calls its `open()`/`reader:read()` to pull
`definitions.lua` out of the pinned cosmos runtime (`_make/seed.tl`
documents this bootstrap). Rewriting `cosmic/zip.tl:open()` to call
`zip.reader(...)` means compiling `cosmic/zip.tl` during that very
bootstrap — before `cosmo/zip.d.tl` has been (re)generated — against
whatever type declaration is already bundled (the pinned
`bin/cosmic.pin` release, or the previous `o/_types/types_gen`),
neither of which has ever seen `zip.reader`. Generating the type that
would let `zip.reader` compile requires first compiling
`cosmic/zip.tl`, which requires that very type. Reproduced
deterministically on a fully clean `o/` (`rm -rf o`, refetch,
rebuild):

```
cosmic/zip.tl:215:25: error: invalid key 'reader' in record 'zip' of type zip
  hint: the value's record type does not declare this key ...
make: _types/types_gen.tl: cannot build o/cosmic/zip.lua
build: FAIL (generate failed)
```

Isolated by reverting just the `zip.tl` edit (pin bump alone, still
calling `zip.open`): the seed/generate step succeeds cleanly,
confirming the failure is specifically `cosmic/zip.tl` consuming a
cosmo binding brand-new in the very pin being bumped, while that same
file participates in the bootstrap that produces the type for it. This
is the same shape of staging problem CLAUDE.md's cold-build rule
describes for a new checker feature ("land the checker first, bump the
pin, then land the code that needs it") — except here the two pieces
(the pin bump, and `zip.tl`'s use of the new binding) are exactly what
this item's own `## Change` asks to land together in one commit, and
no way was found to do that literally without touching
`_types/gentype_defs.tl` itself (out of this item's stated scope), e.g.
by having it read `definitions.lua` via raw `cosmo.zip` instead of the
`cosmic.zip` wrapper — breaking the circularity is its own change,
not attempted here.

A diff implementing the rest of the `## Change` (pin bump +
`cosmic/zip.tl` rewrite + cast-baseline reconciliation) is committed,
unpushed, on branch `3Iw35aAO` at commit `188ad03` for whoever unblocks
this to start from, once the circularity is broken.

## Change

**Blocked** on breaking `_types/gentype_defs.tl`'s circular dependency
on `cosmic/zip.tl` first (its own item, not filed as part of this
bounce — file it separately, scoped to making the type-generation
bootstrap for `zip` read `definitions.lua` via `cosmo.zip` directly
rather than through `cosmic.zip`'s own wrapper, so `cosmic/zip.tl` can
consume a brand-new `cosmo.zip.*` binding in the same pin bump that
introduces it without a cold-build chicken-and-egg). Once that lands:

Ready when: that circularity-breaking item is `done`, AND (unchanged
from before) `VHkK_aA5k` is `done`, a `cosmos` release descends from
it, and `3p/cosmos/cosmos_pin.tl` names that release (already true as
of this bounce — re-verify the pin is still current when this is
picked back up, since more releases may have shipped since).

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
- `bin/cosmic --make ci` ends `ci: PASS` on a COLD build (`rm -rf o`
  first) — a converged/incremental-only green is not sufficient
  evidence here, since that is exactly what this bounce's own failure
  hid.

## Non-goals

Not `unix.fcntl`'s cast (`cosmic/fd.tl:187`) — tracked separately,
pending a `cosmic.fd` API decision `VHkK_aA5k`'s sibling item raises.
Not re-litigating `zip.reader`'s own shape — that is `VHkK_aA5k`'s
scope, already landed by the time this item is ready.
Not breaking the `_types/gentype_defs.tl` circularity here — that is
its own item (see `## Change` above), a prerequisite, not folded in.
