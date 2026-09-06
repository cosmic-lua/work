## Goal

`_types/gentype_defs.tl`'s type-generation bootstrap for `zip`
`require`s `cosmic.zip` and calls its `open()`/`reader:read()` to pull
`definitions.lua` out of the pinned cosmos runtime. That makes
`cosmic/zip.tl` itself part of the bootstrap that generates
`cosmo/zip.d.tl` — so `cosmic/zip.tl` can never be the FIRST consumer
of a brand-new `cosmo.zip.*` binding introduced in the same pin bump
that adds it: generating the type requires compiling `cosmic/zip.tl`
against a type declaration that does not exist until that very
generation runs. Break the circularity so a cosmos pin bump and the
`cosmic/zip.tl` code that consumes its new binding can land in the
same commit, the way every other `cosmic/*.tl` wrapper already can.

## Evidence

Found 2026-09-06 while building board item `Hkal_OAFy` (closing
`cosmic/zip.tl:222`'s cast by switching to the new `zip.reader`
binding once `cosmos` pinned a release carrying it). All three of
`Hkal_OAFy`'s own preconditions held (the binding merged upstream,
carried by a release, the pin bumped to name it), yet a fully clean
build still failed:

```
$ rm -rf o && bin/cosmic --make fetch && bin/cosmic --make build
cosmic/zip.tl:215:25: error: invalid key 'reader' in record 'zip' of type zip
  hint: the value's record type does not declare this key ...
make: _types/types_gen.tl: cannot build o/cosmic/zip.lua
build: FAIL (generate failed)
```

Isolated by reverting only the `cosmic/zip.tl` edit (pin bump alone,
still calling the pre-existing `zip.open`): the seed/generate step
succeeds cleanly on the same bumped pin. So the failure is specific to
`cosmic/zip.tl` consuming a binding introduced in the very pin whose
bump is landing — confirming `cosmic/zip.tl` sits inside
`_types/gentype_defs.tl`'s own bootstrap closure (`_make/seed.tl`
documents the general bootstrap; trace `_types/gentype_defs.tl`'s own
`require("cosmic.zip")` and its `open()`/`reader:read()` calls for the
zip-specific instance of it).

## Change

In `_types/gentype_defs.tl`, replace its use of `cosmic.zip` (the
wrapper) with a direct `cosmo.zip` (or equivalent raw binding) call to
read `definitions.lua` out of the pinned cosmos runtime, so this
generation step no longer depends on compiling `cosmic/zip.tl` first.
Confirm the fix by reproducing `Hkal_OAFy`'s exact failure and showing
it now passes: apply `Hkal_OAFy`'s own diff (still committed, unpushed,
on branch `3Iw35aAO` at commit `188ad03`) on top of this fix, `rm -rf
o`, `bin/cosmic --make fetch && bin/cosmic --make ci`, and confirm
`ci: PASS` on the COLD build (not just an incremental/converged one —
that is exactly what hid this bug the first time).

Gate with `bin/cosmic --make ci` (cold, per above) both with and
without `Hkal_OAFy`'s diff applied, to confirm this change alone does
not regress the ordinary (no-new-binding) zip type-generation path.

## Non-goals

Not `Hkal_OAFy`'s own cast removal — that lands as its own PR once
this unblocks it, reusing the diff already committed on `3Iw35aAO`.
Not a general audit of every other `cosmic/*.tl` wrapper for the same
bootstrap-closure hazard — this item fixes the `zip` instance found by
building; a same-shaped hazard elsewhere (if any) is a separate finding
for a separate item, not scoped here.
