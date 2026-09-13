Per AGENTS.md's update procedure. The release this bump targets now
exists and is named here rather than left to be looked up:

**`2026.08.21-87869141c`** — the push-triggered release for merge commit
`87869141`, which is wave 1 (#267). Published 2026-08-21T09:47Z.

**Take that release and not a later one.** Wave 2 (#268) merged after it
and will publish its own release; the sibling item 3I7LNDrF owns that
bump, and pins advance monotonically, which is why it carries a
`blocked_by` edge to this one. A bump straight to a wave-2 release would
pass this item's acceptance while leaving its sibling with nothing to
do — so if the pin already names a release at or past
`2026.08.21-87869141c` when this is pulled, that is not a licence to
skip ahead: stop and return the item to `plan` with what was found.

1. `3p/cosmos/cosmos_pin.tl` is a `cosmic.literal` table, not a
   two-line file: set `version` to the tag above and
   `platforms["*"].sha` to the sha256 of that release's `cosmos.zip`
   asset (the `url` field templates `{version}`, so it does not change).
2. **Capture the perf baseline before the pin moves.** Step 5's compare
   gate needs a run under the OUTGOING pin, and bumping first destroys
   it. Per the optimize skill:
   `bin/cosmic --make run _perf/run.tl --out o/perf/base.json`.
3. `bin/cosmic --make fetch` (the one verb with a network) lands the new
   pin; `bin/cosmic --make build` regenerates `o/_types/types_gen` from
   the release's embedded `definitions.lua` — the new `unix.landlock_*`
   surface appears in the generated types with no regen step of its own.
4. `o/bin/cosmic --make ci` — fix whatever the new types break (expected
   from wave 1: nothing; the surface is additive).
5. The perf compare gate against the baseline from step 2, per the
   optimize skill's loop — a pin bump is a toolchain change and gets the
   regression check every pin bump gets.
