## Change

`review brief: judge a research handover's board commit, not refuse it`
makes `brief review` render a research review from `result` — the board
commit whose body carries the findings — when the item has no
`handover_head`. The brief it renders then prints three `gitboard verdict
ID KIND --head <board sha> --repo-dir <WORKTREE>` lines, and every one of
them is refused. Measured 2026-09-13 in that item's worktree:

```
$ grep -n 'handover_head\|no commit handover' _work/gitverdict.tl
70:  local handed = it.handover_head or ""
73:      ("REFUSED: %s has no commit handover to judge"):format(id:sub(1, 8)))
```

`cmd_verdict` reads `handover_head` alone, refuses when it is empty, and
verifies `--head` through `commit_evidence.verify_lineage` in the PRODUCT
checkout — which cannot resolve a board commit. So the research review
now has a brief and no way to record its verdict: the reviewer reads the
findings, judges them, runs the command the brief printed, and is told
there is nothing to judge.

Teach `verdict` the same rule `brief` now follows: the commit a review
judges is `handover_head` when recorded, else `result`, and the
repository it lives in follows from which one it was. For a `result`
head, verify `--head` equals `result` exactly and that it is a commit on
the item's own ref (`git merge-base --is-ancestor` in the board
checkout, the same lineage shape `verify_lineage` asks of a product
commit against the claim base); refuse a `--head` that names neither.
`accept` on a research head records the verdict and the head the way it
does for a product commit, and `done` closes it with `--landed` naming
that same board commit — `done`'s landing check (`gitdone.tl`, which
resolves `handover_head` in the product checkout through
`repository_map.resolve`) takes the same head-follows-deliverable
branch, or a research item can never end as `completed`.

`_work/gitverdict_test.tl` gains the research cases: accept and
request-changes on a `result` head; a `--head` that is neither the
handover nor the result refused; a `result` whose sha is not on the
item's ref refused. `_work/gitdone_test.tl` (or its sibling) gains the
`--landed <board sha>` close for an accepted research item.

## Non-goals

The brief itself. `review brief: judge a research handover's board
commit, not refuse it` owns what the brief says; this item makes the
verb the brief points at accept what the brief renders.

The rest of the REVIEW template's diff-shaped wording (the mutation
step, `--repo-dir <WORKTREE>`) for a research review. That item's spec
limited itself to the "what you're reviewing" section and said so; the
remaining wording is a separate, smaller edit once this verb accepts the
head.

Any change to how a PRODUCT commit is verified. `verify_lineage` against
the claim base stays exactly as it is for `handover_head`.
