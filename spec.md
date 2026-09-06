## Goal

Document that a checker-behavior-changing carried `tl` patch (a
`3p/tl/tl_patch/*.tl` entry that makes the checker accept code it
previously rejected) must grep `_build/testdata/gotchas/` for fixtures
matching the pattern it fixes, not just flip the one canary test its
own evidence happened to cite — a fixture set exists specifically to
assert "this pattern is STILL an error," and a patch that fixes that
exact pattern makes such a fixture's ratchet fail in CI even though the
patch's own local build looked green.

## Evidence

Board item `FePr_L4FB` (casts: record-field narrowing — landed
2026-09-06, cosmic-lua/cosmic PR #1743) built and locally verified a
new `narrow-record-field` checker patch, flipped its own cited canary
(`cosmic/teal_test.tl`'s `test_hint_index_through_nil_union`), got a
clean local `bin/cosmic --make ci` PASS, pushed, and only then hit red
CI on GitHub:

```
.coverage/_build/gotchas_test.tl (exit 1):
  test_every_symptom_is_real_and_gated
    o/_build/gotchas_test.lua:129: _build/testdata/gotchas/record-fields-dont-narrow.tl:
    --check types must refuse this fixture — a fixture the checker accepts
    documents a symptom that is not actually an error

.coverage/cosmic/_teal_hints_test.tl (exit 1):
  test_previously_shadowed_sections_now_name_themselves
    o/cosmic/_teal_hints_test.lua:51: _build/testdata/gotchas/record-fields-dont-narrow.tl:
    no hint produced at all
```

`_build/testdata/gotchas/record-fields-dont-narrow.tl` documents
exactly the pattern this patch fixes (a guard on a record field
narrowing nothing) as a REAL, currently-refused-by-the-checker gotcha;
two separate ratchet tests (`_build/gotchas_test.tl`'s
`test_every_symptom_is_real_and_gated`, `cosmic/_teal_hints_test.tl`'s
hint-shadowing test) depend on that fixture staying broken. The
builder's own local run did not catch this because the two test files
in question were not among the ones the builder happened to touch or
re-run individually before the full `--make ci` — the failure only
showed up on GitHub's CI run against the merged ref (see the sibling
item this same session filed about the branch being stale, a
compounding but separate cause).

Fixed by retargeting the fixture (and its `docs/guides/gotchas.md`
section) to the genuine residual case the patch does NOT cover (a
guard two field-accesses deep, `o.mid.inner`, rather than one field off
a plain variable) — the same "flip or retarget the canary" motion the
item's own spec already prescribed for `cosmic/teal_test.tl`'s canary,
just missed for this second, independent encoding of the same fact.

## Change

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

## Non-goals

Not auditing whether other ALREADY-LANDED patches missed this same
step — this item only adds the documentation/checklist step for future
patches; a retroactive audit is separate work if anyone judges it
worth doing.
