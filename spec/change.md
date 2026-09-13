Two files, one new gate function and two branches in `cmd_move`.

1. **`_work/gitgate.tl` gains `land_refusal(it: item.Item): string`**
   — the refusal text for an item entering `land` without a standing
   accept, `nil` when it carries one. It refuses on two grounds, each
   naming what is missing:
   - `(it.verdict or "") ~= "accept"` →
     `a move into land carries a standing accept — <id8> has <what>`,
     where `<what>` is the verdict it does carry or `no verdict`.
   - `(it.pr or 0) == 0` →
     `a move into land names its PR — <id8> names none`.
   `wc -l < _work/gitgate.tl` is 274, so it has the room, and this is
   where `handover_refusal` and `wip_refusal` already live.

2. **`_work/gitverbs.tl` `cmd_move`** gains, beside the existing
   `target == "check"` branches and before the `item.problems` check:

   - `if target == "land" and not force then` → call
     `gate.land_refusal(it)` and return
     `gate.verdict_line("move", false, "REFUSED: " .. refusal)` when
     it fires. `--force` still passes, as it does for every other
     gate, and `--why` is already required with it.
   - beside the existing `if flow.is_return(from, target) then
     it.claim = "" end`: when the return leaves `check` or `land`,
     also clear `it.verdict`, `it.verdict_head` and `it.enable`. A
     leftward move out of the two judged phases means the judgment no
     longer describes the item, and leaving it behind is exactly what
     lets a reworked head merge on an old accept.

   `wc -l < _work/gitverbs.tl` is 464 — 36 lines under the cap, which
   the roughly 12 lines this adds fit inside.

3. **Tests.** `_work/gitgate_test.tl` (88 lines) gains
   `test_land_refusal`, covering an item with an accept and a PR (no
   refusal), one with `request changes`, one with no verdict, and one
   with an accept but `pr == 0`. `_work/gitverbs_test.tl` (408 lines,
   92 under the cap) gains `test_move_into_land_needs_an_accept` and
   `test_return_out_of_land_clears_the_verdict`, the second asserting
   `verdict`, `verdict_head` and `enable` are all `""` after
   `move land do`.
