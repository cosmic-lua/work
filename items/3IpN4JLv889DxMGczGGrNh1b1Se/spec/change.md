`_work/brieftext.tl` is 3 lines under the cap, so first move the review
brief's text (the second `STOP` block at :160 onward, through the
review's mutation-test paragraph at :238) into a new
`_work/brieftext_review.tl` exposing the same function names; the
callers in `_work/brief.tl` import it. Then, in the builder brief:

- step 1 gains one sentence: "Before the first edit, `wc -l` every file
  the Change names; if the Change's additions cannot fit under the
  500-line cap, STOP now (report the count) rather than after
  implementing."
- step 3 gains one sentence: "Between edits, `bin/cosmic --check types
  <file>` on the files you touched; run the full gate once, before the
  push."
- the STOP rule gains one sentence: "Leave your diff committed on the
  item branch (unpushed), never reverted: the respec starts from it."
- step 7 gains one sentence: "If the push or the PR shows a conflict
  with the base branch, stop and report it with the conflicting files;
  merging the base into the item branch is the orchestrator's, never a
  builder's rebase." (One builder in a 2026-09-04 routine pass attempted
  its own `git rebase origin/master`, hit an add/add conflict, abandoned
  it and pushed unrebased; the orchestrator redid the merge from scratch.)

`_work/brieftext_test.tl` (or `brief_test.tl`) pins each of the four sentences with a
`find` assertion, the way the existing `Board:` line is pinned.
