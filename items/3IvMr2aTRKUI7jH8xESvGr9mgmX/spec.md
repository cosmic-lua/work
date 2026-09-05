## Change

`attach ID PARENT` moves ID and leaves ID's entry in its OLD parent's
`order` list, so `fsck` reports "order names ID, which is not a child
of it" after every move of a positioned item; three agents reshaping
the board hit it independently and two tried to hand-edit the blob.
Change `cmd_attach` in `_work/gitgraph.tl`: when ID's current parent
is an item whose `order` names ID, remove the entry and save that
parent in the same publish as the child (and the new parent, when
placement or `containered` already writes it). The old parent is one
more ref in the one leased push; a lost race refuses the whole move.
`rank` needs no change. Update `docs/design/order.md`'s "Moves and
stale entries" section: a stale entry is now a repair case `fsck`
reports, not the normal result of a move. Tests: `gitattach_test.tl`
— a positioned child moved leaves no entry behind, an unpositioned
one writes only the child, a move under the same parent is a no-op.
Measured: `gitboard fsck` on the live board today lists 8 such
entries under `3HyRck1p` and `3HyRdT1J`; `fsck --fix` is not this
item — those 8 are cleared by ranking or by a one-time `rank ID
--last` and back, or left, since reads ignore them.
