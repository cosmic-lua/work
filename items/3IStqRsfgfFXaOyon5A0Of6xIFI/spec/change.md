One guard, in `_work/gitverbs.tl`, plus one regression test.

1. **`_work/gitverbs.tl`** — the block at lines 151-157 reads:

   ```teal
   if target == "check" and not force then
     local refusal = gate.handover_refusal(s, id,
       (pr or 0) ~= 0 and pr or it.pr, it.repo)
   ```

   Extend its condition so the gate runs only when a PR number is
   actually in hand:

   ```teal
   if target == "check" and not force
   and ((pr or 0) ~= 0 or (it.pr or 0) ~= 0) then
   ```

   Nothing else in the block changes. Add a sentence to the comment
   above it (or a new one) saying why: an evidence handover names no
   PR, so there is nothing for this gate to read and nothing for it to
   say — which is not the same as the "cannot see" case
   `_work/gitgate.tl:158-168` deliberately refuses, and leaving that
   property intact for every PR-carrying handover is the reason the
   skip lives at the CALL SITE rather than inside `handover_refusal`.

   Measured now: `wc -l _work/gitverbs.tl` is 297 — 203 lines of
   headroom under the 500-line cap.

2. **`_work/gitverbs_test.tl`** — add one test function,
   `test_an_evidence_handover_asks_github_nothing`, called on the line
   after its `end` like every other test in the file. It must use
   `init_shared` (already bound at `_work/gitverbs_test.tl:23`), NOT
   `init_state_repo`, because a local-only store short-circuits the
   gate this test exists to cover:

   - `local a = init_shared("evidence-origin")` — the first clone;
   - `local _, leaf = root_with_leaf(a)`;
   - write `fixture.READY_SPEC .. "## Result\nMeasured, twice.\n"` to a
     file under `tmpdir` and install it with `verbs.cmd_spec`;
   - `cmd_move(a, leaf, "ready", "", 0, false, "")`, then
     `cmd_move(a, leaf, "do", "session-a", 0, false, "")`;
   - `assert(verbs.cmd_move(a, leaf, "check", "", 0, false, "", true) == 0)`
     — this is the assertion that fails today;
   - assert the loaded item's `phase == "check"` and `pr == 0`.

   Measured now: `wc -l _work/gitverbs_test.tl` is 380 — 120 lines of
   headroom.
