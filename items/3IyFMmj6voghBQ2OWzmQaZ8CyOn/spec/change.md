`_work/brieftext_review.tl`: a third template `REVIEW_SCRIPT`,
chosen by `_work/brief.tl` when the PR's `get_files` names no `.tl`
file outside `*_test.tl`, or fewer than 20 changed lines in total
(`gh.pull`'s `additions + deletions`): the same header and verdict
block as `REVIEW`, with "How to review" replaced by the four numbered
moves above and the mutation paragraph replaced by "break the guard
in a copy of the file taken with `git show <head>:<path>`, never in a
worktree, and confirm the refusal". `_work/brieftext_test.tl`: the
script template contains "git show" and lacks "fresh checkout";
`_work/brief_test.tl`: a 2-line pin diff selects it, a 200-line `.tl`
diff selects `REVIEW`.
