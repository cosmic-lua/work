After a `request changes` verdict, re-claiming the item to do the rework is
refused by two guards that cannot both be satisfied once `main` has moved past
the branch point — which it does routinely, because other items land while this
one is in review.

Measured, on «9cnW_GG8u» after its review. `main` had advanced to `a8383e991a5a`
(two sibling items merged); the board's handover was `ae9577c324805ef39a3b9cb8b4306b91189c4e78`
on the work branch.

With `main` current:

    gitboard claim 9cnW_GG8u --session $BUILDER --repo-dir $WORKTREE --fetch-base
    refused 3JN5eP0y…: 3JN5eP0y already has a commit handover (ae9577c32480…) that
    local a8383e991a5a (a8383e991a5a) cannot reach — a fresh review claim must not
    silently capture an unrelated base; reposition main in $WORKTREE to (or behind)
    the handover (e.g. `git -C $WORKTREE update-ref refs/heads/main ae9577c32480…`),
    then retry `claim --repo-dir $WORKTREE`

Following that advice exactly:

    git -C $WORKTREE update-ref refs/heads/main 0e6970867a8e…   # the branch's true base
    gitboard claim 9cnW_GG8u --session $BUILDER --repo-dir $WORKTREE
    refused 3JN5eP0y…: local main (0e6970867a8e) is behind its tracking ref
    (a8383e991a5a) — run `git -C $WORKTREE fetch` then `git -C $WORKTREE update-ref
    refs/heads/main a8383e991a5a`, or re-run claim with --fetch-base to do it here

Each refusal's remedy is the other refusal's cause. The second fires with or
without `--fetch-base` (both were tried), so there is no flag combination that
satisfies both. `take` cannot be used to break the cycle either: it refuses with
`REFUSED: 3JN5eP0y's handover belongs to its claim holder`, so the rework cannot
be handed over without first holding a claim.

The guards are individually right. A fresh claim must not capture a base
unrelated to the outstanding handover, and a claim must not record a stale base.
What is missing is that a REWORK is neither case: it continues from the
handover, not from `main`.

Give the rework its own base. In `_work/gitclaim_cli.tl`'s `product_base`
(`grep -n "local function product_base" _work/gitclaim_cli.tl`), when the item
already carries a `handover_head` and its verdict is `request changes`, use that
handover as the claim's product base instead of the local `main` tip, and skip
the behind-tracking-ref check for that case: the handover is by definition the
commit the rework continues from, and it is immutable board state rather than a
local ref that can be stale.

Both existing refusals stay exactly as they are for every other path — a first
claim, a review claim on an item with no outstanding rework, and a claim whose
item has no handover at all.

Regression: `_work/gitclaim_rework_base_test.tl` builds an item through
claim → handover → request-changes, advances the product repository's `main`
past the handover, and asserts the re-claim succeeds and records the handover as
its product base. Assert the negative too: the same advance WITHOUT a
request-changes verdict still refuses, so the escape hatch is scoped to rework.

It is a TWO-STAGE trap, not one awkward verb. The workaround for the deadlock
records a BRANCH commit as the claim's product base, and `done` then refuses
the completion:

    gitboard done 9cnW_GG8u --landed 3fd0445882ed… --reason completed --session …
    gitboard-done: REFUSED: landed commit 3fd0445882ed… forks from a8383e991a5a…,
    which does not descend from claim base 6c254a380db6…

Because this repository squashes on merge, NO branch commit is ever an ancestor
of `main` (`git merge-base --is-ancestor <handover> origin/main` → false), so
that descent check is unsatisfiable for any claim whose base came from the
workaround — and a clean re-claim to repair the base hits the deadlock again.
The only exit was `done --force --why`.

So every reworked item in this repository needs a forced completion until this
is fixed, and each forced completion is an audited escape recorded against work
that was in fact landed and verified. That is the cost of leaving it open, and
it is why this is worth more than its "one awkward verb" first reading.
