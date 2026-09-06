## Evidence

An orchestrator filling a wave needs every pullable item with its repo,
to judge file-disjointness across the wave. `gitboard show` prints the
todo head only: `_work/gitview.tl:109` `TODO_SHOWN < const > = 8`, and
line 240 prints `  ... %d more` for the rest — this board's `show` says
`todo 209 (83 pullable)` and renders 8 rows. `next` names one item and
up to three "or:" alternatives. No verb lists the other 75 pullable
rows. On 2026-09-06 (work4) the orchestrator spent 8 tool calls
writing a query over `o/board.db`'s `queue`/`search` views to get the
list `show` already computes (`pullable_ids`, gitview.tl:220-228).

`wc -l _work/gitview.tl` → 497 (3 lines under the cap), so the change
there must be line-neutral or move code out; `_work/gitshow.tl` → 340.

## Change

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

## Non-goals

No new ordering, filter, or column. No change to `next`.
