## Change

`next` still calls `store.list`, which hydrates every item (1000 on
the bench fixture, 1049 live) into `item.Item` records through
`cachequery.items` before `action.next_action` reads one `queue` row
set — the hydration exists only because `decision.Action.item` is an
`Item` the renders print. Change the contract: `Action.item` becomes
the id plus the fields the renders use (handle, title, repo, base,
state), read from the queue row, and `next`'s render hydrates the one
or two items it names with `store.load` only where it needs the full
record (the brief). `show` (the board) makes the same move for its
doing/todo/triage lists, which already come from `queue`/`triage`
rows. Measure: bench `next`/`show` before and after, and the count of
`Item` records built per `next` (add a counter in a test, not in
production code).
