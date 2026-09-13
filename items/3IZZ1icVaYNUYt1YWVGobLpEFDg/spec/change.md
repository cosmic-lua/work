Sketch, not a settled design — the shape to aim at is a third handover
that records a sha on the item the way `--pr` records a number.

**A `--commit SHA` flag on `move`.** It sits beside `--pr N` and
`--evidence` in `cmd_move`'s signature and in `gitboard help move`, and
it satisfies the same `target == "check"` bar the other two do. The
gate at `_work/gitverbs.tl:174` grows a third arm, and its first
refusal line grows a third clause naming it.

**An item field to record it.** `item.Item` carries `pr: integer`
(`_work/item.tl:69`, parsed at `:230`); the parallel is a `commit:
string`, written by the same path that writes `it.pr` at
`_work/gitverbs.tl:254` and by `gitgate.set_in_place`
(`_work/gitgate.tl:288-290`). `gitview.tl:80` renders `pr:%d` in the board
marks and would render the short sha the same way.

**What the reviewer is pointed at.** A sha alone is enough to find the
diff only if the base is known; recording the parent, or accepting a
`BASE..HEAD` range, is the open question. Resolving it against the
local repo at handover time — the commit must exist and be an ancestor
of the branch tip — is the analogue of the accept-time PR-state read
and is worth considering, but is a decision this item has to make, not
one it inherits.

**The landing half.** `land` reads `it.pr` and asks GitHub whether the
PR merged (`_work/gitland.tl:53-77`); `gitverdict.tl:194` already ends
a PR-less item on accept rather than parking it in `land`. A
commit-carrying item is closer to the second — the commit is already
on `board` at handover time, so there is nothing left to wait for —
but which of the two paths it takes is part of this item's decision.
