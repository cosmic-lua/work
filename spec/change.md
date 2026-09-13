Add a line to whichever doc governs writing/landing a `3p/tl/tl_patch/`
entry (CLAUDE.md's Language and Conventions section, or a
`docs/decisions/d21-carried-tl-patch.md` implementation note): before
opening the PR, `grep -rl` the pattern the patch fixes across
`_build/testdata/gotchas/*.tl` (not just the one canary test file the
item's own spec happened to cite) and, for every match, either retarget
the fixture to a genuine residual case or drop it if the whole gotcha
is now fully closed — the same motion `docs/guides/gotchas.md` and
`_build/gotchas_test.tl`'s own ratchet already expect for a closed
gotcha, just not yet stated as a checklist step for a patch author to
follow proactively.
