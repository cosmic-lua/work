In `_work/flow.tl`'s `untriaged`, drop the `not has_open_children(...)`
condition — an item's own children being open says nothing about
whether IT is placed; `rank.is_ranked` already carries the placement
check. Confirm no caller relies on the current filtering-out behavior
as a feature (`_work/gitview.tl:210-212`'s dashboard render and any
other `flow.untriaged` call site) — if one specifically wants
"unranked AND childless" for its own reason, it should express that
itself rather than reuse a general-purpose `untriaged` that quietly
narrows the definition of "untriaged." Add a case to
`_work/flow_test.tl`: an unranked board-level item WITH an open child
still appears in `untriaged()`'s result.
