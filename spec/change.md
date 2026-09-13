One file, `.github/workflows/release.yml`, four edits plus a guard,
each mirroring `size.json`'s existing treatment exactly. Re-locate each
site by its `size.json` neighbour rather than by the line numbers
above, which move.

1. **Artifact path list** (`:231-234`): add `o/perf/selfcheck.json`
   beside `o/perf/perf.json`.
2. **Source discovery** (beside `size_src=`): add
   `selfcheck_src=$(find artifacts -type f -name selfcheck.json | head -1)`.
3. **The guard** (the `if [ -z "$cosmic_src" ] || …` chain): add
   `[ -z "$selfcheck_src" ]` as another disjunct, so a missing file
   fails the release rather than publishing a partial asset set — which
   is the property that chain exists for.
4. **Stage it** (beside `cp "$size_src" release/size.json`): add
   `cp "$selfcheck_src" release/selfcheck.json`.
5. **Publish it** (the `gh release create` argument list): add
   `release/selfcheck.json` beside `release/perf.json`.

6. **Rewrite the comment block above the "measure the release" step** —
   REWRITE, not append. The block's existing sentence, "run twice — once
   for the record, once so the compare step below has an A/A self-check
   to separate a real regression from noise", is the stale claim
   `3IHHKCyz` filed against: the gate never reads that file's
   pre-measured content, it overwrites it. Leaving it in place and
   adding prose beside it produces a block that contradicts itself, and
   the block is this change's whole non-mechanical payload.

   The rewritten block must state, in one voice and without
   contradiction:

   - both readings are published, so each release retains its own
     same-binary A/A control — two full-suite measurements of one binary
     on one runner in one job — and a release runner's noise floor can
     be read after the fact;
   - on a CLEAN run the published pair is the measure step's two
     readings;
   - on an ESCALATED run the gate OVERWRITES `selfcheck.json` with its
     own control measurement of the same binary and reads THAT as a
     triage control (`_perf/gate.tl`'s `controls`, D31), so a published
     pair's halves may be minutes or tens of minutes apart;
   - publishing adds no gate input: nothing reads the RELEASED asset.

   Do not write a flat "nothing gates on the second half". It is false
   on an escalated run under one reading and makes "both readings are
   published" false under the other — the escalated case has to be
   named, not generalised away. Write it to the house standard
   (`skills/docs-style/SKILL.md`) — no item ids, no PR numbers, no
   dates.
