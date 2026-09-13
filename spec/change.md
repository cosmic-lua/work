The distance guard: a session that built or specced an item is never
offered — and cannot record — its verdict, and no session holds two
live claims. Reads the involvement record the blocking sibling
(3IVCd39E's re-spec) lands; blocked on it.

Measure at pull time, after the sibling lands:

1. Review-claim derivation (`_work/gitverbs.tl` cmd_take's
   take_review branch) additionally refuses when `session` appears
   in `it.builders` or `it.speccers`:
   `REFUSED: <session> built/specced <id8> — the verdict needs a
   fresh context`. The refusal logic lives in `_work/gitgate.tl`
   (291 lines, room) as one predicate both callers share.
2. `_work/gitverdict.tl`: the same predicate refuses recording a
   verdict when the recording session is in builders/speccers, with
   `--force --why` as the repair escape (audited in the log via the
   existing forced_suffix grammar).
3. One live claim per session name: a take that would CLAIM an item
   (not a review-claim, not a re-take of the session's own item)
   refuses when the session already holds a live claim on another
   open item: `REFUSED: <session> already holds <other-id8> — one
   claim per worker; drop it or finish it first`. This is the
   collision alarm 3IMk60ar's remaining half asked for: two runners
   sharing a name now collide loudly at the second take instead of
   silently corrupting mutual exclusion.
4. `_work/action.tl`: next_action's review offer applies the same
   builders/speccers exclusion, so `next` never offers what take
   refuses (the lesson PR 1523 already taught this machinery once).
5. Tests: builder-cannot-review-claim (derivation steps past to the
   next candidate), speccer-cannot-review-claim, verdict refusal for
   builder and speccer, forced verdict records with the forced
   suffix, second-claim refusal (and: a re-take of the session's OWN
   claimed item still succeeds — rework handovers depend on it; and
   a review-claim while holding a build claim still succeeds — the
   orchestrator pattern depends on... NO: verify against the skill:
   a review subagent names ITSELF uniquely, so a review-claim
   coexisting with a build claim under one name is not a supported
   pattern; decide from the skill's text and pin whichever way it
   says, stating the choice in the test's comment). Mutation-verify
   each guard red.
