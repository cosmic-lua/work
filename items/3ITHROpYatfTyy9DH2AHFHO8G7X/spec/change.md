No source file changes anywhere. The deliverable is recorded evidence
and one follow-up item.

1. **Six scratch worktrees, one fixed tree.** From the cosmic
   checkout, make six worktrees detached at **`5ef13f40`**, one per
   release tag in the table above. In each, edit ONLY the `version`
   and `platforms["*"].sha` lines of `3p/cosmos/cosmos_pin.tl`.
   Obtain each sha first-party: download the tag's `cosmos.zip`,
   `sha256sum` it, and cross-check that digest against the same
   release's `SHA256SUMS` asset. If the two disagree, stop and record
   that as the result — never write a sha from anywhere else. The two
   pins listed under `## Evidence` are already first-party and may be
   used as-is.

2. **Fetch every arm and hash its runtime.** In each worktree run
   `bin/cosmic --make fetch`, then `sha256sum o/3p/cosmos/lua`. Record
   all six digests. This step is cheap — no build — and it is what
   decides how many arms get measured.

3. **Collapse the inert commits.** Walk the six arms in commit order,
   `07fc94a1c` first. An arm whose `o/3p/cosmos/lua` digest is
   byte-identical to its immediate predecessor's cannot have moved
   anything: drop it and attribute its commit to the surviving arm
   before it. Call the surviving arms after `07fc94a1c` the
   CANDIDATES. Record every digest and every collapse in the result,
   including the case where nothing collapses.

4. **Choose the arms to measure, capped at four.**
   - If there are **three or fewer candidates**: measure `07fc94a1c`
     plus every candidate.
   - If there are **four or more candidates**: measure exactly three —
     `07fc94a1c`, the middle candidate (index `ceil(n/2)` in commit
     order, 1-based), and `354c17e08`.

   Never measure more than four arms in this slice; a surviving range
   is what the follow-up in (8) is for.

5. **Build the measured arms.** In each measured worktree,
   `bin/cosmic --make build`, reading the `build: PASS` verdict line
   directly and never through a pipe. Then `sha256sum o/bin/cosmic`:
   the measured arms' digests must all differ, and a repeat means two
   arms measured the same binary and the result is void.

   **If an arm refuses to build**, record the exact failure verbatim
   as a result and drop that arm, keeping `07fc94a1c` and
   `354c17e08` — they are the pair the whole finding rests on. Do NOT
   edit the tree to make an arm build, and do NOT substitute another
   tree commit: either makes this a different experiment.

6. **The noise floor, per measured arm, first.** In each measured
   worktree, twice:

   ```
   o/bin/cosmic --make run _perf/gate.tl selfcheck \
     o/perf/aa-1.json o/perf/aa-2.json --only codec_base64_roundtrip_64k
   ```

   Record each pass's reported per-scenario delta. `floor` is the
   LARGEST absolute delta any pass on any arm showed.

7. **The readings.** Four isolated readings per measured arm,
   ALTERNATING round-robin across arms — never all of one arm then
   all of the next — each its own process:

   ```
   o/bin/cosmic --make run _perf/run.tl --only codec_base64_roundtrip_64k \
     --out o/perf/<tag>-<n>.json
   ```

   Use the default `--samples`/`--min-secs`. Nothing else heavy may
   run on the machine during the readings. Record every reading's
   µs/op and its reported `±`, in run order.

   **The verdict rule, and no other.** Let `med(X)` be an arm's median
   of its four readings. For each measured arm `X` after `07fc94a1c`,
   the step is **REPRODUCED at X** iff all three hold:

   - `med(X) > med(07fc94a1c)`;
   - the two arms' four-reading ranges do not overlap;
   - `(med(X) - med(07fc94a1c)) / med(07fc94a1c) * 100 > floor`.

   Otherwise **NOT REPRODUCED at X**. State each arm's verdict with
   the three numbers that decided it. The step lands at the EARLIEST
   arm in commit order that reads REPRODUCED; the answer is that
   arm's commit together with every commit collapsed into it in (3)
   and every unmeasured commit between it and the previous measured
   arm.

8. **Write the result onto this item** with
   `gitboard spec 3ITHROpY FILE`, run from the `board` worktree.
   Replace the sidecar with these five sections unchanged plus a
   sixth, `## Result`, appended last — do not delete `## Evidence`, a
   result that erases what it was measured against cannot be re-read.
   `## Result` carries, in this order and in these shapes, because
   `Acceptance` counts them:

   - one line per FETCHED arm, starting at column 1, spelled exactly
     `- runtime <tag> <64 hex digits>` — the `o/3p/cosmos/lua` digest
     from (2);
   - one line per MEASURED arm, spelled exactly
     `- cosmic <tag> <64 hex digits>` — the `o/bin/cosmic` digest
     from (5);
   - the collapse from (3) in prose, naming which commits collapsed
     into which arm, or saying plainly that none did — prose, not a
     table, because the readings table is the only table `Acceptance`
     expects to find here;
   - one line per MEASURED arm, spelled exactly
     `- selfcheck <tag> <pass 1 delta> <pass 2 delta>`, then one line
     spelled exactly `- floor <pct>%` carrying the largest absolute
     delta any pass on any arm showed;
   - the readings as the section's ONLY markdown table, header and
     rows starting at column 1 (`| run | arm | µs/op | ± |`), one row
     per reading, in run order, each row's first cell a two-digit run
     number (`| 01 |`);
   - one line per measured arm after `07fc94a1c`, reading
     `<tag>: REPRODUCED — med 191.31 → 209.35 µs (+9.44%), ranges
     disjoint, floor 4.5%` or `<tag>: NOT REPRODUCED — ...`, with the
     three numbers the rule decided on;
   - one line starting at column 1 spelled exactly
     `moved-by: <commit-or-range>` — a single commit sha when the
     bisect landed on one, or `<sha>..<sha>` when a range survives;
   - one line starting at column 1 spelled exactly
     `follow-up: <id>` naming the item filed in (9);
   - one closing paragraph saying what the evidence supports and what
     it does not.

9. **File exactly one follow-up**, with
   `gitboard new "<title>" --parent 3HyRcW05 --spec-file F`, where F
   is one paragraph of evidence quoting the medians and the floor:

   - **a single commit identified** → file the fix: read that commit's
     diff, test the layout hypothesis against it, and land any fix in
     whilp/cosmopolitan without moving a binding contract.
   - **a range survives** (the cap in (4) split it, or an arm was
     dropped in (5)) → file the next bisect slice, naming the
     surviving range and its commit count.
   - **nothing reads REPRODUCED at any arm** → file that: the step
     did not reproduce on this hardware at all, which contradicts
     `3ISlWFiS` and is itself the finding.
