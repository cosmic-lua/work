`gitboard snapshot` (`_work/snapshot_cli.tl`) prints one `existing-spec-issue`
line per pre-existing readiness issue in the publication plan's report — on
the live board that is several hundred lines and thousands of tokens on every
inspection, ahead of the verdict line the caller actually reads. Print only the
compact report line (it already carries `existing-spec-issues=N`) and the
`new-spec-issue` lines by default; list the existing issues only under a new
`--issues` flag on `snapshot`, registered in `_work/gitcommands.tl` beside
`--check`. `--check` keeps its verdict. Say so in `snapshot`'s help synopsis.

Regression in `_work/snapshot_feedback_test.tl` or a sibling: a board with
one pre-existing readiness issue and one issue the composition introduces;
default output carries the count and the `new-spec-issue` line and no
`existing-spec-issue` line; `--issues` prints it.
