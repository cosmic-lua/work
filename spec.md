## Evidence

`IXiQ_JbjO`'s rework closed the 409 case: `_work/ghland.tl`'s `is_held_back`
is now `HTTP 405` only, because a 409 is GitHub reporting that the branch
head disagrees with the sha `merge_pull` guarded the request with — the
reviewed commit is not the commit that would land.

Its re-reviewer (commit `61ec14dd`) found the same danger survives one step
to the side, and flagged it as non-blocking only because the spec mandated
the fallback verbatim and it is unchanged from the base commit:

> `merge_pull`'s 409 proves a sha mismatch, but a 405 ("not mergeable") does
> not prove the sha *matched*; and auto-merge is head-unguarded by
> construction, so it lands whatever head is current when checks clear.

Both arming paths are head-blind: `enable_auto_merge`'s GraphQL payload is
`{pullRequestId, mergeMethod}` with no `expectedHeadOid` (`_work/ghwrite.tl`),
and its CCR REST fallback (`PUT .../ccr/auto_merge`) carries no sha either.
So a 405 refusal followed by arming schedules whatever head is current at
merge time — which need not be the head the reviewer judged.

The remedy costs no extra request: `gh.pull`, already called on the arming
path to fetch the node id, also returns `p.head_sha` (`_work/review.tl`),
and `_work/review.tl` already carries a moved-head predicate.

## Change

In `_work/ghland.tl`'s arming path: after reading the request for its node
id, compare `p.head_sha` against the judged head. Arm auto-merge only when
they agree; when they disagree, land nothing and report it the same way a
409 is now reported — the reviewed commit is not what would land, so the
caller decides by hand.

Add a case: a 405 refusal whose subsequent request read shows a head other
than the judged one sends no arming mutation and reports the mismatch. Keep
the existing 405-with-matching-head case arming as it does today.

## Non-goals

Not revisiting the 405/409 split itself — that is settled. Not adding
`expectedHeadOid` to `ghwrite.enable_auto_merge`'s payload: worth doing
eventually so the guard lives at the mutation rather than at its caller, but
the CCR REST fallback has no such field, so the two paths would diverge in
strength; this item puts the check where both paths share it.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
