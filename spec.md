## Evidence

Reviews this pass split by shape, measured with `cosmic
_tool/friction.tl` on each transcript: a mechanical diff (a two-line
pin, three prose sentences, a 15-line sh block) reviewed from a
numbered script with a checkout-free mutation cost 8, 10 and 11
calls; the same generic template on the same size of diff cost 31-36
(PRs 58, 59). The script had four fixed moves: read the diff and check
runs, verify the one measured fact the spec names, break the guard in
a scratch copy (`git show <head>:<file>` into the scratchpad) and
watch it refuse, record. `_work/brieftext_review.tl` has one `REVIEW`
template (`grep -c 'local REVIEW' _work/brieftext_review.tl` → 1) and
no shape keyed on the diff.

## Change

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

## Non-goals

No change to `REVIEW`'s posture; no size threshold above 20 lines.

## Access

cosmic-lua/work and cosmic-lua/cosmic, read only: the PR's file list
and line counts through the existing `_work.gh` client.
