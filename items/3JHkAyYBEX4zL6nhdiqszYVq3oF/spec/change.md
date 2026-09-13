`gitboard set ID --repo OWNER/NAME` with no `--touches` and no `--access`
rewrites the item's `touches` and `access` lists to empty. Observed on the
live board on 2026-09-13: `set 3JHjKxy2 --repo cosmic-lua/work` produced
the commit `set 3JHjKxy2 repo touches access` and the item's `meta` lost
its `touches:` line (the parent commit's `meta` carried
`touches: _work/boardtree.tl _work/boardtree_test.tl`). `_work/gitset.tl`
is correct — it updates a list only when the argument is not nil
(`grep -n "if touches ~= nil then" _work/gitset.tl`) — so the dispatcher
passes an empty table where the flag was absent. Fix in the dispatch
branch for `set` in `_work/gitboard.tl` (`grep -n '"set"' _work/gitboard.tl`):
pass nil when the repeatable flag was not given, exactly as `title` and
`repo` already arrive nil, and add a regression to `_work/gitset_test.tl`
(or the CLI test that exercises `set`): a `set --repo` on an item with a
non-empty `touches` leaves `touches` unchanged and the subject names only
`repo`. Then the help line `each REPLACES its whole list rather than
appending to it` (`grep -n "REPLACES its whole list" _work/gitcommands.tl`)
is true as written.
