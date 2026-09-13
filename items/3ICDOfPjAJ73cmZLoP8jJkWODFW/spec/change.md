Two files. Keep the signature additive — no call-site sweep.

1. **`_work/gitgate.tl`: `commit_and_publish` gains two optional
   trailing parameters**, `force?: boolean` and `vacated?: string`,
   after the existing `also?: {item.Item}`. Inside the revalidate:
   - when `force` is true, return nil immediately — the force
     authorised this arrival and a rebase does not un-authorise it;
   - pass `vacated` into the limit test the way `gate.wip_refusal`
     already takes it, so a net-zero decomposition is credited after
     the rebase exactly as it was before.

   `wc -l < _work/gitgate.tl` is 346, so there are 154 lines of
   headroom; this adds roughly 15.

2. **`_work/gitverbs.tl`: two call sites.**
   - `cmd_attach` passes the item's ACTUAL phase as `from` instead of
     `nil`, so a re-parent that leaves the item where it stands is
     classified as a non-arriving write and stays editable on a full
     column.
   - `cmd_move`, `cmd_new` and `cmd_done` pass their `force` through;
     `cmd_new` also passes its `vacated` value.

   `wc -l < _work/gitverbs.tl` is 479 — 21 lines of headroom, which
   the roughly 6 lines of extra arguments fit inside. **Do not grow
   this file further**; if a change here needs more than that,
   stop and report rather than restructuring the file.

3. **Tests.** `_work/gitgate_test.tl` (117 lines) already builds the
   lost-race fixture (`init_shared`, `fill_plan_over_limit`) and is
   the right home for all three. Add:
   - `test_force_survives_a_lost_race` — a forced arrival into an
     over-limit column publishes after losing the race.
   - `test_a_reparent_is_not_an_arrival` — a `from` equal to the
     item's phase survives the same race (the #1287 class, now for
     attach).
   - `test_vacated_credit_survives_a_lost_race` — an entry carrying
     `vacated` publishes into an over-limit column after the rebase.
