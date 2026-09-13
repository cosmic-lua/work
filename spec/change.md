`_make/seed.tl`'s `run` now promotes the staged seed directly into the
one path every compile channel already consults with no flag at all.

Previously `run` left the generator's unclosed output sitting at
`SEED_DIR` (`o/_types/types_seed`) — a location only `_make/closure.tl`'s
`--include-dir` flag, attached to the ONE explicit compile of a
generator SCRIPT's own top-level closure, ever names. Everything else
this Evidence traced — `main.tl`'s own unconditional
`require("_cli.main_handlers")`, and any `cosmic/*.tl` a generator's
subsequent execution reaches through the interpreted searcher — never
receives that flag, so it falls through `_teal_engine`'s
`default_include_dirs()` to the fallback: the RUNNING (pinned, pre-bump)
binary's bundled `/zip/.types`.

`default_include_dirs()` already hardcodes `o/_types/types_gen` FIRST,
unconditionally, on every project's compile path — that's the one
directory every consumer this item found (explicit-flag or searcher
alike) already looks at with nothing extra to wire up. So instead of
teaching more call sites about the seed's separate location, `run` now
does one `fs.move` of the complete, successfully-seeded `SEED_DIR`
straight onto `TYPES_GEN_DIR` (`o/_types/types_gen`) itself, atomically,
once the seed generator succeeds. `should_seed` already only calls
`run` when `TYPES_GEN_DIR` is absent (or a prior run's `SEED_DIR` was
left dangling), so there is never a real directory here for the rename
to clobber — and the later real run of `_types/types_gen.tl` in
`generate.sources`'s own generator loop still unconditionally clears
and repopulates `TYPES_GEN_DIR` with the complete, closure-checked
output, exactly as it always has; the promoted seed is only ever the
bridge that gets every OTHER compile in between past the gap.

`_make/seed_test.tl`'s `test_run_populates_and_cleanup_removes_the_seed_dir`
is renamed `test_run_populates_and_promotes_to_types_gen_dir` and
rewritten to match: after `run`, `SEED_DIR` is gone (promoted away, not
left behind) and the generator's own output lives at the newly-exported
`seed.TYPES_GEN_DIR` instead; `cleanup` afterward is asserted as the
no-op it now is on that path.

**Why this can't be proven against a genuinely cold build on the
CURRENT pin, and what was proven instead**: `_make/*.tl` is embedded,
precompiled, in the pinned bootstrap binary and frozen for generation 1
— confirmed directly: `o/bootstrap/cosmic -e 'require("_make.seed")...'`
silently returns the OLD code with no trace of a tree-source debug print
added for the check, and a genuinely cold `rm -rf o` build never emits
it either. This is the identical situation `3IkSSqvH`'s own D43 fix
was already in (AGENTS.md's cold-build rule: "Such a change stages
behind a release and pin bump: land the checker first, bump
`bin/cosmic.pin` to a release carrying it, then land the code that
needs it") — a tree-source change to `_make/*.tl` cannot alter what
generation 1 of THIS pin does; it only takes effect once a release built
from a tree carrying it becomes the new pin.

Validated instead the way that constraint allows: built `o/bin/cosmic`
(generation 2, compiled from tree source, which DOES embed this fix) via
a completely cold `rm -rf o && bin/cosmic --make fetch && bin/cosmic
--make build` against this branch's UNCHANGED, un-bumped `3p/cosmos`
pin — `build: PASS (605 files, 1 binary)`, converging in the normal two
generations with no manual intervention. Then, to specifically exercise
the promote-on-seed path itself (which the current, un-bumped pin has no
occasion to trigger — `o/_types/types_gen` is already fresh once
generation 2 exists), removed only `o/_types` and reran `o/bin/cosmic
--make build` alone: it reseeded, promoted, and rebuilt cleanly with no
stale-type failure and no manual step — the exact self-heal this fix is
for, proven on the one binary available to prove it on before the next
pin bump embeds it for real. `o/bin/cosmic --make ci` afterward:
`ci: PASS (5 stages)`, 3286/3286 tests, coverage ratchet holds,
including `_build/coldbuild_test.tl` — the gate that specifically
re-checks generation 1's exact type-check behavior with the pinned
checker and tree module resolution.

Does not itself unblock `3IkMf7BY1UOxBTAIwbNFQwRZJDA`: that item's
cold build, against the ACTUAL bumped `3p/cosmos` pin, still needs a
new cosmic release cut from a tree carrying this fix, and
`bin/cosmic.pin` bumped to it, before ITS generation 1 sees any of
this — same staging `3IkSSqvH` went through. This item only lands the
mechanism.
