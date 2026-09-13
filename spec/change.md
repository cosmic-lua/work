No source file changes anywhere. The deliverable is a `## Result`
section on this item and one follow-up item.

1. **Four scratch worktrees, one fixed tree.** From the cosmic
   checkout, make four worktrees detached at **`5ef13f40`**, one per
   row of the pin table in `## Evidence`. In each, edit ONLY the
   `version` and `platforms["*"].sha` lines of
   `3p/cosmos/cosmos_pin.tl`, to that row's tag and sha verbatim. Do
   not compute a sha from anywhere else; if `--make fetch` rejects one,
   record the refusal verbatim as the result and stop.

2. **Fetch and hash each runtime.** In each worktree run
   `bin/cosmic --make fetch`, then `sha256sum o/3p/cosmos/lua`. Record
   all four digests. The four must differ; a repeat means two arms
   resolved the same runtime and the result is void, which is itself
   the finding to record.

3. **Build each arm.** In each worktree, `bin/cosmic --make build`,
   reading the `build: PASS` verdict line directly and never through a
   pipe. Then `sha256sum o/bin/cosmic`: the four digests must all
   differ, and a repeat voids the result the same way.

   **If an arm refuses to build**, record the exact failure verbatim
   as a result and drop that arm, keeping the base `07fc94a1c` and
   `354c17e08` — they are the pair the whole finding rests on. Do NOT
   edit the tree to make an arm build, and do NOT substitute another
   tree commit: either makes this a different experiment. A dropped
   arm leaves a range, which is what the follow-up in (9) covers.

4. **The noise floor, per arm, before any reading.** In each worktree,
   twice:

   ```
   o/bin/cosmic --make run _perf/gate.tl selfcheck \
     o/perf/aa-1.json o/perf/aa-2.json --only codec_base64_roundtrip_64k
   ```

   Record each pass's reported per-scenario delta. `floor` is the
   LARGEST absolute delta any pass on any arm showed.

5. **The readings: NINE per arm, round-robin.** Nine isolated readings
   per arm, cycling base → c1 → c2 → c3 → base → … so each round
   samples every arm once — never all of one arm then all of the next.
   Each reading is its own process:

   ```
   o/bin/cosmic --make run _perf/run.tl --only codec_base64_roundtrip_64k \
     --out o/perf/<tag>-<n>.json
   ```

   Use the default `--samples`/`--min-secs`. Nothing else heavy may run
   on the machine during the readings. Record every reading's µs/op and
   its reported `±`, in run order.

   Nine, not four, is the change that answers `3ITHROpY`'s failure: it
   is the smallest odd count that leaves a seven-reading body after the
   trim in (6) discards one reading from each tail.

6. **The verdict rule, and no other.** For each arm `X`, sort its nine
   readings ascending as `r1 … r9` and take:

   - `med(X) = r5` — the median;
   - `lo(X) = r2` — the trimmed minimum, discarding the single fastest;
   - `hi(X) = r8` — the trimmed maximum, discarding the single slowest.

   A candidate arm `X` reads **REPRODUCED** iff all three hold:

   - `med(X) > med(base)`;
   - `lo(X) > hi(base)` — the two arms' TRIMMED ranges are disjoint;
   - `(med(X) - med(base)) / med(base) * 100 > floor`.

   Otherwise **NOT REPRODUCED at X**. State each candidate's verdict
   with the three numbers that decided it. This is `3ITHROpY`'s rule
   with exactly one condition hardened: disjointness is judged on the
   trimmed range, so a single outlier reading in either arm can no
   longer veto a separation. Nothing else about the instrument moved.

   Also record each arm's raw minimum `r1` in the readings summary. It
   decides NOTHING — timing noise is one-sided, so the minimum is the
   least-contaminated estimate and is worth carrying to the next pass,
   but the three conditions above are the whole rule.

   **The answer** is the EARLIEST candidate in commit order
   (`5bfcf79d0`, then `8dd093cea`, then `354c17e08`) that reads
   REPRODUCED — that arm's single commit, because all three candidates
   are measured and no unmeasured commit lies between them. A later
   candidate also reading REPRODUCED is additional movement after the
   step, not ambiguity: say so in prose and leave the answer at the
   earliest. If an arm was dropped in (3), the answer is the range from
   the last NOT REPRODUCED arm to the earliest REPRODUCED one.

7. **If no candidate reads REPRODUCED**, that is the result: record it
   with the same three numbers per arm, set `moved-by:` to
   `8e071ec98..354c17e08`, and file the escalation described in (9).
   Do not re-run the readings hoping for a quieter host, do not widen
   the reading count, and do not restate the rule — each is a decision
   this spec encodes, and changing one mid-slice is what `plan` exists
   to prevent.

8. **Write the result onto this item** with
   `gitboard spec 3ITOUv0w FILE`, run from the `board` worktree.
   Replace the sidecar with the five sections above unchanged plus a
   sixth, `## Result`, appended last — do not delete `## Evidence`, a
   result that erases what it was measured against cannot be re-read.
   `## Result` carries, in this order and in these shapes, because
   `Acceptance` counts them:

   - one line per arm, starting at column 1, spelled exactly
     `- runtime <tag> <64 hex digits>` — the `o/3p/cosmos/lua` digest
     from (2);
   - one line per arm, spelled exactly
     `- cosmic <tag> <64 hex digits>` — the `o/bin/cosmic` digest
     from (3);
   - one line per arm, spelled exactly
     `- selfcheck <tag> <pass 1 delta> <pass 2 delta>`, then one line
     spelled exactly `- floor <pct>%` carrying the largest absolute
     delta any pass on any arm showed;
   - the readings as the section's ONLY markdown table, header and rows
     starting at column 1 (`| run | arm | µs/op | ± |`), one row per
     reading, in run order, each row's first cell a two-digit run
     number (`| 01 |`);
   - one line per arm, spelled exactly
     `- stats <tag> min <r1> lo <r2> med <r5> hi <r8>`, in µs;
   - one line per CANDIDATE arm, reading
     `<tag>: REPRODUCED — med 143.43 → 180.28 µs (+25.70%), trimmed
     ranges disjoint (hi base 145.24 < lo X 167.03), floor 6.5%` or
     `<tag>: NOT REPRODUCED — ...`, with the three numbers the rule
     decided on;
   - one line starting at column 1 spelled exactly
     `moved-by: <commit-or-range>` — a single commit sha when the
     bisect landed on one, or `<sha>..<sha>` when a range survives;
   - one line starting at column 1 spelled exactly
     `follow-up: <id>` naming the item filed in (9);
   - one closing paragraph saying what the evidence supports and what
     it does not.

9. **File exactly one follow-up**, with
   `gitboard new "<title>" --parent 3HyRcW05 --spec-file F`, where F is
   one paragraph of evidence quoting the medians, the trimmed ranges
   and the floor:

   - **a single commit identified** → file the fix: read that commit's
     diff, test the layout hypothesis against it, and land any fix in
     whilp/cosmopolitan without moving a binding contract.
   - **a range survives** (an arm was dropped in (3)) → file the next
     bisect slice, naming the surviving range and its commit count.
   - **nothing reads REPRODUCED** → file the escalation: the trimmed
     rule did not separate the three candidates on this host either, so
     the next pass needs a different instrument (a quieter host, or a
     scenario shaped so the effect is not swamped), and the fix cannot
     be attributed until it does.
