Resolve the fallback branch from the item's `base` field when it is set,
before the `origin/HEAD` and `main`/`master` ladder, and pass that field
through from `_work/gitshow.tl` alongside the claim base it already
passes. Share one implementation with `_work/brief.tl`'s `BASE_BRANCH`
resolution rather than leaving the heuristic written twice.

Reword `absent:` so it says what was actually judged — the resolved
commit, not "the tree" — matching the `unreadable:` line's phrasing. Name
the resolved commit in the headroom output once, so a reader can tell
which state the lines describe.

Add cases: an item whose `base` names a non-default branch measures
against that branch rather than the default tip; and the reworded
`absent:` line, asserted for a path absent at the resolved commit but
present in the working tree — the case that today asserts the misleading
wording.
