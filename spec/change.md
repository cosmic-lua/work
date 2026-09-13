Research slice: the deliverable is recorded evidence and the follow-up it seeds,
not a code diff. Done in ONE session, later than 2026-08-22.

1. **Obtain the two binaries and hash them.** Download the A binary to
   `o/perf/A-cosmic-lua`, verify its sha256; build B with `bin/cosmic --make
   build`. Record `sha256sum` of both.
2. **Interleave five A/B pairings of the isolated scenario.** Alternate WHOLE
   measure cycles — A, B, A, B, … — per `skills/optimize/cosmopolitan.md:143`.
   Each cycle is one `_perf/run.tl --only tar_extract_tree` at default
   `--samples`/`--min-secs`, writing its own results file under `o/perf/`.
3. **Establish this session's noise floor** with `_perf/gate.tl selfcheck` on
   the B binary, `--only tar_extract_tree`. That A/A spread is the threshold the
   A/B delta must beat.
4. **Record the outcome on the item, verbatim** — both sha256s, the ten
   readings beside the 2026-08-22 five, the selfcheck spread, the date.
5. **Take the branch the decision rule selects.**
   - *Reproduced* (B slower than A in every pairing AND the delta exceeds the
     selfcheck spread): file one follow-up capture proposing a `perf record`
     bisect of the two cosmos pins on `lua.dbg`, then `done`.
   - *Not reproduced* (B within A's spread or faster in any pairing; or the
     delta inside the selfcheck spread): `done` with the evidence recorded, no
     follow-up.

**Branch taken: Not reproduced.** Pair 5 has B faster than A, and four of five
deltas are inside the ±24.2% self-check band.
