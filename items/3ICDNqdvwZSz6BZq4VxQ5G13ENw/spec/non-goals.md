- `flow.admits_over_limit` does not change: land stays exempt from the
  WIP limit, because an accept is a decision already made.
- `_work/gitverdict.tl` is not touched. An accept's own move into land
  is the verdict verb's, not `cmd_move`'s, and it writes the accept
  the new gate asks for — gating it there would refuse every real
  accept.
- `_work/gitland.tl` is not touched. Comparing `verdict_head` against
  the PR head at merge, and passing GitHub's `sha` guard, is item
  3ICDNJmQ's slice; this one stops a stale accept from ever reaching
  `land`, which is a different hole in the same wall.
- No change to the `gitboard-move:` verdict line format — `status` and
  the skill both read it.
- Returns stay unrefusable. This adds no gate to leftward motion; it
  only makes leftward motion drop what it invalidates.
