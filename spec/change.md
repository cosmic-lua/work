In `cosmic/embed/init.tl`, replace the current all-or-nothing embed
policy (currently: every `.lua` entry stored, everything else
deflated, per `plaA_uCdm`'s dropped attempt to flip it to all-deflate)
with a policy that stores exactly the measured boot-path set and
deflates everything else:

1. Enumerate the boot read set the same way `plaA_uCdm`'s evidence did
   (`./cosmic-lua -e 'for k in pairs(package.loaded) do print(k) end'`
   against a built `cosmic-lua`, filtered to the modules that resolve
   from `/zip`) and re-measure it against the current tree — the set
   may have moved since 2026-08-29.
2. In the embed policy (the `AddOptions` loop around
   `cosmic/embed/init.tl:380-397`), replace the current `is_lua`
   store-everything-`.lua` branch with a check against that boot-path
   set: an embedded entry gets `method = "store"` only when its module
   path is in the boot set (plus whatever non-`.lua` entries the
   existing policy already stores, if any — check the current code
   rather than assuming), and `method = "deflate"` otherwise. Update
   the policy comment above the loop to state the new policy and the
   measured boot set it is keyed to.
3. Update `cosmic/embed_test.tl` (the test currently pinning embedded
   `.lua` at method 0/stored, per `plaA_uCdm`'s notes at lines 336-357)
   to assert the new per-entry split: boot-set entries stored, the rest
   (including `.docs/index.lua` and `tl.lua`) deflated.
4. Performance is the one thing `--make ci` cannot judge: run the loop
   in `skills/optimize/SKILL.md` — baseline `origin/main`, change, A/A
   selfcheck, compare gate — on both `startup_run_lua` (must NOT
   regress, since the whole point is to avoid `plaA_uCdm`'s regression)
   and the size scenario/measurement (must show most of the ~2.0MB win,
   since `.docs/index.lua` and `tl.lua` — the two dominant entries — are
   outside the boot set and stay deflated). Keep only on a pass on both
   axes; never weaken either scenario or its check to pass.
