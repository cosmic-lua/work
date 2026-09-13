The involvement record: the board writes down who BUILT and who
SPECCED an item, because the no-self-review guarantee can only be
derived from records that exist. Measured 2026-08-29: `_work/item.tl`
declares `builders: {string}` (line 72, encode/decode/problems all
present) but `grep -rn "builders" _work/*.tl | grep -v _test` shows
NO verb writes it — the two-state rewrite dropped the append, so
review distance today rests on the live claim alone. Spec authorship
was never recorded at all (the incident: a session was offered the
review of a decision it wrote — evidence preserved in item 3IY2Bj90).

1. `_work/gitverbs.tl` `cmd_take`: on the CLAIM paths — pull,
   handover (`--pr`), rework return, forced takeover — append
   `session` to `it.builders` when absent. NEVER on the derived
   review-claim path (a reviewer is not a builder; appending there
   would wrongly bar them from... nothing today, but it poisons the
   record the guard item reads). gitverbs.tl is at 494/500: if the
   append does not fit inline, put a
   `record_involvement(it, session)` helper in `_work/item.tl` (375
   lines) and call it — one line at the call site.
2. `_work/item.tl`: new `speccers: {string}` field, encoded exactly
   like builders (space-joined, no repeats, same problems check).
3. `_work/gitverbs.tl` `cmd_spec`: append `session` to `it.speccers`
   when absent, and commit the ITEM file alongside the sidecar in
   the same mutation (today spec commits touch only the .md —
   measure how cmd_spec stages and extend it).
4. Tests (in `_work/gitclaim_test.tl` or `gitverbs_test.tl` —
   measure headroom): a pull appends the builder once (a second
   take by the same session does not duplicate); a handover take
   appends; a review-claim take does NOT append; cmd_spec appends
   the speccer and a second spec by the same session does not
   duplicate; decode round-trip for speccers. Mutation-verify: drop
   the builders append — a test goes red; drop the speccers append —
   a test goes red; make the review-claim path append — the
   not-append test goes red.
