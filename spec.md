## Evidence

`help build`'s prescribed path for an out-of-scope finding mid-build is
`new --parent <ID>` — file it as a child, orchestrator's job, builder
never files its own. Hit twice this session on items that already had
an OPEN PR awaiting review: `wAe5_evHa` (PR #1791) and `9R8e_zA8Q`
(PR #78/rework). In both cases, filing the child silently promoted the
item from `role: work` to `role: container` — and a container is
refused by `take` for its review claim: `gitboard-take: <id> is a
container — only workable leaves are taken`, even though the item's own
PR is perfectly fine and just needs a verdict. `help review`'s own
"reject that reopens a decision" path documents this exact
work→container transition, but only for a REJECT (where blocking the
item until the child resolves is the intended effect) — filing a
routine, non-blocking out-of-scope finding shouldn't have the same
side effect on an item whose diff is otherwise ready to land.

The workaround found live: `attach <child> <grandparent>` immediately
after `new --parent`, re-parenting the finding one level up. That
reverts the item to `role: work`/its prior `state` and un-blocks `take`
— confirmed both times (`wAe5_evHa` showed `role: work, state: review`
again after the re-parent; `9R8e_zA8Q` likewise). Costs one extra verb
call per finding filed on an in-review item, and is easy to miss —
nothing in `help build` or `help review` mentions that filing a child
this way has this side effect at all, so a session without this
session's own prior discovery would likely stall on the container
refusal.

## Change

`new --parent ID`: when ID already carries an open `pr:`/is in `state:
review` or `state: rework` (not a bare `todo`/`plan`), filing a child
does NOT promote it to `role: container` — the item keeps its
`role: work` and its live claim/PR exactly as they were; the new child
is simply attached and stays independently pullable. The
role→container promotion remains exactly as it is today for every
other case (a plain `todo`/`plan` item gaining its first child, and the
documented reject-that-reopens-a-decision path via `verdict ... reject`
followed by `new --parent`+`drop`).

## Non-goals

Not changing the reject path's own container semantics — a reject that
reopens a decision should still block the item on its child, exactly as
`help review` documents. Not changing `attach`'s re-parenting behavior,
which already works correctly as the interim workaround.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
