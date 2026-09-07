## Evidence

work#71 («Qa2H_5whT») makes `gitboard verdict request-changes`/`reject` post a `COMMENT` review (first body line `request-changes:`/`reject:`) when the PR's author is the token's own login, because GitHub refuses `REQUEST_CHANGES` on one's own PR (cosmic#1768). `_work/gh.tl`'s `latest_request_changes` was taught the marker, so `brief.tl`'s `bounce_context`/`round_context` still find the bounce. But `_work/brief.tl`'s `round_context` (about lines 276–281 at work#71's head) computes `ROUND_NUMBER` for `<ROUND_CONTEXT>` by counting reviews with `state == "CHANGES_REQUESTED"` only. An own-PR bounce round lands as `COMMENTED`, so a rework cycle that included one under-counts its round: the resumed reviewer reads "round 1" on what is round 2. The builder reported it out of scope for #71 (its Change named only `latest_request_changes`).

## Change

`round_context` counts a review as a bounce round when its state is `CHANGES_REQUESTED` OR it is a `COMMENTED` review whose body's first line carries the `request-changes:`/`reject:` marker — the same predicate `latest_request_changes` uses, lifted into one shared helper in `gh.tl` (a `is_bounce_review(r)` or similar) so the two cannot drift again. `_work/brief_rework_test.tl` gains a case: two bounces, one formal and one marked COMMENT, yield `ROUND_NUMBER` 3 on the next round.

## Non-goals

No change to what `verdict` posts; no change to the marker format; no new brief text.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`bin/cosmic --make ci` green in the work checkout, the new test present, and `grep -n CHANGES_REQUESTED _work/brief.tl` shows no second copy of the predicate.
