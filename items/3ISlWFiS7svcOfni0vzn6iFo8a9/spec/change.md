No source file changes. The deliverable is recorded evidence.

1. **Three arms, one fixed tree.** Work in three scratch worktrees of
   the cosmic checkout, all at cosmic commit **`5ef13f40`** — the same
   tree `3ISWHyP7` used, so the only differences from that run are the
   session, the container and the pin set:

   | arm | `3p/cosmos/cosmos_pin.tl` version | what it is |
   |---|---|---|
   | A | `2026.08.21-07fc94a1c` | the published release's pin, the gate's baseline arm |
   | B | `2026.08.24-354c17e08` | the pin `3ISWHyP7` accused |
   | C | `2026.08.26-fe7c36c4c` | main's pin today, the gate's current arm |

   In each worktree edit only the `version` and `platforms["*"].sha`
   lines of `3p/cosmos/cosmos_pin.tl` (the sha is the `cosmos.zip`
   asset's, taken from that release — never copied from a third
   party), then `bin/cosmic --make fetch && bin/cosmic --make build`.
   Read the `build: PASS` verdict line directly, never through a pipe.

   **If arm C refuses to build** — `5ef13f40` predates
   `bfe422e9` ("cosmos: consume the exact contracts"), so a newer
   runtime's `definitions.lua` may not agree with that tree's
   `_types/gentype.tl` MODULES list — then record the exact failure
   verbatim as a result, drop arm C, and run the slice as the two-arm
   A/B. Do NOT edit the tree to make arm C build: changing the tree
   breaks the "only the pin varies" property the whole measurement
   rests on. Do NOT substitute a different tree commit either; a
   changed tree makes this a different experiment, not this one.

2. **Record which binary each arm is.** `sha256sum o/bin/cosmic` in
   each worktree; the three (or two) hashes must differ. Quote them
   in the result. Never use `--version` to tell the arms apart — it
   stamps the pin at embed time, not the runtime
   (`skills/optimize/cosmopolitan.md` step 2).

3. **The noise floor, per arm, first.** In each worktree:

   ```
   o/bin/cosmic --make run _perf/gate.tl selfcheck \
     o/perf/aa-1.json o/perf/aa-2.json --only codec_base64_roundtrip_64k
   ```

   Run it twice per arm. Record the reported per-scenario delta of
   each pass — that is this container's same-binary swing for this
   scenario in THIS session, and it is what the decision rule in (5)
   measures the effect against.

4. **The readings.** Four isolated readings per arm, ALTERNATING
   between arms round-robin (A B C A B C A B C A B C — never all of
   one arm then all of the next), each its own process:

   ```
   o/bin/cosmic --make run _perf/run.tl --only codec_base64_roundtrip_64k \
     --out o/perf/<arm>-<n>.json
   ```

   Use the default `--samples`/`--min-secs`. Nothing else heavy may
   run on the machine during the readings. Record every reading's
   µs/op and its reported `±`, in run order, in a table like the one
   under `## Evidence`.

5. **The verdict, by this rule and no other.** Let `med(X)` be an
   arm's median of its four readings and `floor` be the LARGEST
   same-binary delta any arm's selfcheck passes showed in (3). For
   each ordered arm pair (A→B, A→C, B→C) the regression is
   **REPRODUCED** iff all three hold:

   - `med(later) > med(earlier)`;
   - the two arms' four-reading ranges do not overlap;
   - `(med(later) - med(earlier)) / med(earlier) * 100 > floor`.

   Otherwise that pair is **NOT REPRODUCED**. State each pair's
   verdict with the three numbers that decided it. A→C is the pair
   that matters to the release lane; say so explicitly.

6. **Write the result onto this item.** Replace this spec sidecar
   (`gitboard spec 3ISlWFiS FILE`, run from the `board` worktree)
   with the same five sections unchanged plus a sixth, `## Result`,
   appended last. Do not delete `## Evidence` — a result that erases
   what it was measured against cannot be re-read. `## Result`
   carries, in this order and in these shapes, because `Acceptance`
   counts them:

   - one line per arm, starting at column 1, spelled exactly
     `- sha256 <arm> <64 hex digits>` — e.g.
     `- sha256 A 1b54fceb...`;
   - the selfcheck floor: each arm's two passes' reported
     per-scenario deltas, and the LARGEST of them named as `floor`;
   - the readings as one markdown table whose header and rows start
     at column 1 (`| run | arm | µs/op | ± |`), one row per reading,
     in run order;
   - one line per ordered arm pair reading
     `A→C: REPRODUCED — med 193.46 → 208.58 µs (+7.8%), ranges
     disjoint, floor 4.8%` or `A→C: NOT REPRODUCED — ...`, with the
     three numbers rule (5) decided on;
   - one closing paragraph saying what the evidence now supports and
     what it does not.

7. **File exactly the follow-up the result implies**, with
   `gitboard new "<title>" --parent 3HyRcW05 --spec-file F`, where F
   is one paragraph of evidence quoting the numbers:

   - **A→C reproduced** → file the bisect: which commit in
     `07fc94a1c..fe7c36c4c` moved it, by building
     `o//tool/lua/lua` in a whilp/cosmopolitan checkout at each
     candidate and standing it in at `o/3p/cosmos/lua`
     (`skills/optimize/cosmopolitan.md` step 2). Name the range and
     the commit count in the spec-file paragraph.
   - **A→C not reproduced** → file nothing new; say in `## Result`
     that the block reason recorded on `3ISVlHT6` no longer binds and
     leave the edge for the reviewer.
