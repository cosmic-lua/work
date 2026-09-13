Two notes the review of cosmic-lua/work#166 accepted with on record:

1. `_work/readddl.tl`'s stage arm reads `w.title LIKE 'lane repair: % is red'`
   while `_work/flow.tl`'s `is_lane_repair` reads
   `title:match("^lane repair: .+ is red$")`. SQLite's `LIKE` is
   case-insensitive for ASCII and accepts an empty lane, so a hand-titled
   `Lane Repair: fuzz.yml is red` under G8 ranks at stage 5 but is neither
   exempt from review debt nor found by `lanes.is_repair_for`. No such row
   exists on the live board. Fix: `w.title GLOB 'lane repair: * is red'`
   (case-sensitive; the pattern carries no `*`, `?` or `[`), and one
   `read_test` case with a `Lane Repair: …` title under `flow.LANE_PARENT`
   expecting stage 6. Leave the empty-lane edge: `file_repair` only ever
   writes the fixed `LANES` names.
2. `is_lane_repair`'s parent half is untested at the gate: with `parent`
   ignored, no test goes red, so a repair-titled item under any other
   outcome would be exempt from review debt. Add one `gitgate_test`
   assertion — `make_item({title = flow.repair_title("x")})` under an
   ordinary parent is still held under debt — so `flow.tl`'s "both halves
   are required" sentence is load-bearing.
