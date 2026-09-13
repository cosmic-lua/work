`gitboard show --todo N`: N todo rows instead of 8; `--todo 0` means
every todo row. Rows keep today's shape (`«handle» title [pullable]
[repo]`), so the `[pullable]` mark reaches every row instead of the
first eight. The `... N more` line prints only when rows remain.

- `_work/gitview.tl`: `TODO_SHOWN` stops being a file constant and
  becomes a parameter of the board renderer (default 8; 0 = all). Keep
  the file at or under 500 lines: the constant's three doc lines pay
  for the parameter, and if the count still lands over, move
  `id_line` and its doc comment to `_work/tail.tl` (its `handle` is
  the only thing it calls).
- `_work/gitshow.tl` `cmd_show` and `_work/gitcommands.tl`'s `show`
  entry: parse `--todo N` (integer, ≥ 0; anything else is a usage
  refusal on the verdict line) and pass it through. No effect with an
  ID argument.
- `_work/gitview_test.tl` (or `gitshow_test.tl`, whichever has ≥ 30
  lines of headroom — measure first): a board of 10 todo items renders
  8 rows and `... 2 more` by default, 10 rows and no trailer with
  `--todo 0`, 3 rows and `... 7 more` with `--todo 3`.
- `gitboard help show` and `gitboard help orchestrate`'s "Disjoint or
  not at all" bullet: name `show --todo 0` as the way to see the whole
  pullable set.
