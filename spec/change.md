The claim stays a single-valued lease; what becomes durable is the
record of who has held it.

1. **`_work/item.tl` gains `builders: {string}`** on `Item` — every
   session that has held the claim on this item, oldest first,
   deduplicated. Stored the way `beats` and `blocked_by` already are:
   one space-joined string, decoded with `gmatch("%S+")` and encoded
   with `table.concat(it.builders, " ")`, omitted when empty. Session
   names carry no spaces (`claude-i66dkr`, `sched-n4i2ns`, `dji1my`),
   so the existing idiom holds. `problems` gains one rule beside the
   `blocked_by` and `beats` loops: `builders` repeating a name is a
   problem; it is NOT restricted to ksuids. `builders` is not listed
   in the "claim/pr/verdict/repo belong to worked items, not roots"
   rule — a root never gets one, because a root never takes a claim.
   `wc -l < _work/item.tl` is 275.

2. **`_work/gitverbs.tl` `cmd_move` appends before it writes.**
   Wherever `it.claim` is set from the `--claim` flag, append that
   session to `it.builders` when it is not already the last entry.
   The clear-on-return branch (`flow.is_return`) keeps clearing
   `claim` and does NOT touch `builders`: dropping the lease is the
   point of a return, and forgetting who built is the bug.
   `wc -l < _work/gitverbs.tl` is 464.

3. **`_work/gitverbs.tl` `cmd_move` refuses an in-place takeover.**
   When `from == target`, the move already refuses; the new refusal is
   for a claimed item whose `--claim` names a different session while
   the claim is live, i.e. `target == "do"`, `(it.claim or "") ~= ""`,
   `claim ~= it.claim`. Message:
   `REFUSED: <id8> is claimed by <A> — take over a live claim with --force --why`.
   `--force` performs the takeover and still appends to `builders`, so
   the takeover is legible in the log and the earlier builder stays
   disqualified.

4. **`_work/action.tl` `reviewable` consults `builders`.** Replace the
   `(i.claim or "") == session` test with "this session has held this
   item": the claim OR any entry in `builders`. A helper
   `built_by(i: item.Item, session: string): boolean` beside
   `reviewable` keeps the test in one place. The `mine` counter's
   meaning is unchanged — items in `check` this session built — it is
   now correct where it was optimistic. `wc -l < _work/action.tl` is
   458, 42 under the cap, which a helper of about eight lines fits.

5. **Tests.** `_work/item_test.tl` (203 lines) gains
   `test_builders_round_trip` (decode of a space-joined string, encode
   omitting an empty list, `problems` on a repeat).
   `_work/gitverbs_test.tl` (408 lines) gains
   `test_claim_appends_a_builder`, `test_return_keeps_builders`, and
   `test_live_claim_needs_force`. `_work/action_test.tl` (377 lines)
   gains `test_reviewable_skips_a_past_builder`, which reproduces the
   sequence above: A claims, the item returns, B claims, the item
   reaches `check`, and `reviewable` withholds it from A.
