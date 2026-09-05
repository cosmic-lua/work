## Evidence

While building a labeled duplicate/control fixture for
3IsofrTyVSLXpZtxrx5Ng6qdpp2 (the similarity-signal research item), the
researching session found at least 5 more unlinked duplicate/overlap
pairs on the live board, incidentally, while selecting "unrelated
control" candidates — not from an exhaustive search. Each was verified
via `gitboard show`'s `resolution`/`pr` fields and spec text:

- `3IivQnBPZ9I9mAsg3RLPYh0N81a` (not-planned) / `3IjRa88PfMHXoRab5q1vZjeIuTa`
  (completed, PR #331) — both about `unix.setitimer`'s slot-sharing.
- `3IivH1ReR29JyndVEQT3tYOz9j0` (not-planned) / `3IjRZ9hD9NrStsAnyhMzwK6ZzAh`
  (completed, PR #324) — both about `unix.sigprocmask`.
- `3IivGicDtKhJFBM9YBKv2I9C9c3` (not-planned) / `3IjRXqZek8XKx2W0Dn0GHwNmLjA`
  (completed) — both about `unix.raise`.
- `3IivRILsJk55h3SiLxsrmfINkD3` (not-planned, "Same as the unix.gmtime
  capture") and `3IivR0lb5tIJnJCWQlcxGXb5nx2` (also not-planned), both
  superseded by the combined `3IjRaU2dA8zH56DfC1og37HbOug` ("unix.gmtime
  and unix.localtime return one table...").
- `3IPXgUee0TrlCzUNyO9m2WzeCZ3` (not-planned root, "the board worktree
  lives at o/board...") overlaps `3INdAhKbcbth5tnLkchQXEtS1oz` (completed,
  PR #1541, "...lives in o/...").

None of these are acted on here. All are already resolved (each
`not-planned` item is already superseded by its `completed`/`resolved`
sibling), so there is no board-state conflict to fix — the value here
is the PATTERN: a `not-planned` resolution filed same-day as a
`completed` sibling proposing the identical concrete change is a
strong, cheaply-checkable signal of an unlinked duplicate that a sweep
could flag going forward. This is evidence for, not a duplicate of,
«va0I_6MWO» (the whole-board duplicate/overlap sweep item, currently
blocked on «XSDr_DioY») — that item's own `find.similar`-based approach
won't catch these (per 3IsofrTyVSLXpZtxrx5Ng6qdpp2's own measurement,
lexical similarity cannot separate a real duplicate from a
same-template-family control), so this specific signal — a
`not-planned` item whose spec text contains a supersession phrase
("same as", "same shape as") pointing near a `completed` sibling — is
a distinct, additional heuristic worth folding into that sweep's design
once it is unblocked, or into `gitboard fsck`.

## Non-goals

Acting on any of the 5 pairs above — each is already correctly
resolved; deciding whether this heuristic becomes part of «va0I_6MWO»
or a separate `fsck` check — that is for whoever refines either item
next.
