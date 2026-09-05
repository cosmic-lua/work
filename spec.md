## Goal

`gitboard attach` reparents an item (`it.parent = parent`) but never
removes the item from its PREVIOUS parent's `order` list, leaving a
dangling entry `fsck` flags as `<parent8>: order names <id>, which is
not a child of it`. The item itself ends up correct (right `parent`,
right derived `role`/`state`), but the old parent's `order` field keeps
naming a child it no longer has — permanently, since nothing else ever
prunes it.

## Evidence

Reproduced live on the board's own state today (`cosmic-lua/work`,
`GITBOARD_DIR=/home/user/work`):

```
$ bin/gitboard fsck
3HyRck1p: order names 3IHCM4K287IRCASKd4AlabM88fF, which is not a child of it
3HyRck1p: order names 3ICDKhO3jMQvMwzvJLFGslp9xqq, which is not a child of it
3HyRck1p: order names 3ICInA37GTkn124c60wM2oan7au, which is not a child of it
3HyRck1p: order names 3I1j7yQAawHLQwtQA1bp1i3tUj4, which is not a child of it
3HyRck1p: order names 3IOFqDrgSsC439FA8SAp3wPh7v0, which is not a child of it
3HyRck1p: order names 3IOGXIBquCyDhIY8ckvVJvvqAA7, which is not a child of it
3HyRdT1J: order names 3IIm7ZyNiGaoHsru09SkxFtbsTF, which is not a child of it
3HyRdT1J: order names 3I29nhZCsHYICGr2fafPxMMmVMH, which is not a child of it
3IvHv59h: order names 3IvKn37AOZ6vS9JDu0gHlZWzWbs, which is not a child of it
3IvHv59h: order names 3IvPlZJbR1ORFZt4jvHEcp3zyae, which is not a child of it
gitboard-fsck: 10 problem(s)
```

The last two are freshly reproduced: before running
`bin/gitboard attach 3IvKn37AOZ6vS9JDu0gHlZWzWbs 3HyRcW05wBip6Wqcz145bUQBTyj`
(and the analogous attach of `3IvPlZJb...` under `3HyRdT1J...`), `fsck`
reported 8 problems, all under `3HyRck1p` (6) and `3HyRdT1J` (2) — pre-existing,
from earlier reparents this session did not perform. After the two attach
calls above, the count went to 10: exactly the 2 new dangling `order`
entries under the board (`3IvHv59h`), one per attach, naming the ids just
reparented away from it.

`bin/gitboard show <reparented-id>` after each attach confirms the
child side is correct — `parent` is the new parent, `role` is `work`,
`state` is `todo` — so the defect is isolated to the OLD parent's
`order` field never being pruned.

Root cause, read at `_work/gitgraph.tl:189-253` (`cmd_attach`): line 219
sets `it.parent = parent` on the child; lines 229-237 add the child to
the NEW parent's `order` only when `before`/`after` was passed
(`rank.place_under`, gated into `also` for `gitgate.commit_and_publish`).
Nothing in `cmd_attach` looks up whichever item currently lists `id` in
its `order` (the old parent) to strip it out in the same commit. The 8
pre-existing dangling rows under `3HyRck1p`/`3HyRdT1J` show this is not
new — every past `attach` of an already-ranked child has left the same
kind of residue, silently, since nothing but `fsck` ever looks at the
whole board's `order` fields.

## Change

In `_work/gitgraph.tl`'s `cmd_attach`, after resolving `it` and before
`gate.commit_and_publish`, find whichever item in `index` currently has
`id` in its `order` list (there is at most one, since `order` should be
a partition by construction) and, if it is not `parent_item` itself,
remove `id` from that item's `order` and add it to `also` (the
`gate.containered`/`add_once` set already used for the new-parent case
at line 236) so the edit rides the same commit. Add a case to
`_work/gitattach_test.tl` that: ranks a child under outcome A
(`rank ID --last`), attaches it to outcome B with neither `--before`
nor `--after`, then asserts `fsck` reports zero problems and A's
`order` (read via `store.list`) no longer contains `ID`. Extend
`_work/gitfsck_test.tl` (if it does not already) with a case that
seeds exactly this stale-order shape and asserts `fsck` catches it —
guarding the detector this item's own reproduction relied on.

## Non-goals

Not fixing the 8 pre-existing dangling rows already on the live board
(`3HyRck1p` x6, `3HyRdT1J` x2) — those are data to repair once the tool
stops creating new ones, not part of this change's diff.
