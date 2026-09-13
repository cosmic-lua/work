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
