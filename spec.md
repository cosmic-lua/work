## Evidence

`gitboard worktree ID` branches, bootstraps and fetches without
checking that the caller holds ID's claim: twice this pass it ran to
completion for an item whose `take` had just been refused (7zgt_hrqC
at 19:15, J0zb_occu at 19:52), leaving a branch and a warm checkout
for work nobody could start. `help worktree` says "run right after
`take ID` succeeds"; `git grep -n 'claim' -- _work/gitworktree.tl` →
no hit.

## Change

`_work/gitworktree.tl`, before any git or network call: refuse on the
verdict line — `gitboard-worktree: REFUSED: <id8> is not claimed by
<session> — take it first` — unless the item's claim is the caller's
(the same owner rule `gitowner` applies to `take --pr`). The
`--session` option `take` accepts is accepted here too.
`_work/gitworktree_test.tl`: an unclaimed fixture item → the refusal,
no branch created; a claimed one → today's behaviour.

## Non-goals

No change to bootstrap or `--ref`.
