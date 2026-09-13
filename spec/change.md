1. `_work/priority.tl`: `sorted(list, pos, seed?)` — an optional seed
   replaces the final id tiebreak with a seeded-hash tiebreak, so
   items the comparator ties (same band, own, unblocks) order
   differently per session while every judged ordering stands.
2. `_work/flow.tl`: `queued` passes the seed through.
3. `_work/decision.tl`: `Action` gains `alternates: {Action}`.
4. `_work/action.tl`: the phased half returns up to K=4 candidates
   (land, then reviewable, then finishable, then pullable capped at
   free `do` slots), primary first, crossing rungs when the top rung
   is thin. `unheld` skips blocked `do` items (they cannot be
   finished). The starvation rule fires before intake only when it
   BINDS (`ready` at limit with every member blocked); otherwise
   intake runs first and starvation is the fallback when intake has
   nothing.
5. `_work/gitview.tl`: `next` prints alternates under the guidance.
6. `_work/gittake.tl` (new) + `next --take`: claim the offered
   candidate in the same invocation — `review` for a review, `move
   do --claim` for a pull — walking the candidate list on refusal
   (the CAS/claim refusal is the collision signal), re-syncing and
   recomputing once when the list exhausts. Non-claimable kinds
   report as today.
7. `_work/gitgate.tl` `set_in_place`: overwriting a live foreign
   claim in place now needs `--force --why`, the same rule the move
   verb applies — closes the observed silent-takeover hole.
8. Tests: `_work/action_pick_test.tl` (new; starvation binds vs
   falls back, the do-blocked fallback, blocked finish skip,
   alternates shape and caps, and the seeded tiebreak properties —
   the file exercising `prio.sorted` directly, so the seeded pins
   live here rather than in `_work/priority_test.tl`),
   `_work/gitclaim_test.tl` (the in-place guard; the test pinning
   the old silent overwrite updates), `_work/gittake_test.tl` (new;
   take claims, walks past a lost candidate, and the walk itself is
   mutation-killable via the parked-finish fixture).
9. `docs/flow-review.md`: the starvation-rule change recorded with
   its tripwire.
