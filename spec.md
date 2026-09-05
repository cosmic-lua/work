## Change

`gitboard show <board-id>` prints `bar: <id> is a board, not
workable` and then ends with the verdict `gitboard-show: <id> is
todo`. The board is the one parentless item and has no state. In
`_work/gitshow.tl`, derive the verdict's state word from `flow.role`
first — `board` and `outcome` print their role, not a state — and
suppress the `bar: spec: Change is missing or empty` line for both,
since neither is ever taken. One test in `_work/gitshow_test.tl` per
role. Measured: run `show` on the board item on this board and paste
the two lines into the PR.
