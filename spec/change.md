`_work/gitworktree.tl`, before any git or network call: refuse on the
verdict line — `gitboard-worktree: REFUSED: <id8> is not claimed by
<session> — take it first` — unless the item's claim is the caller's
(the same owner rule `gitowner` applies to `take --pr`). The
`--session` option `take` accepts is accepted here too.
`_work/gitworktree_test.tl`: an unclaimed fixture item → the refusal,
no branch created; a claimed one → today's behaviour.
