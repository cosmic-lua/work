- No change to `lsqlite_config` (see the sibling capture for
  `lsqlite3.config`'s own, separate slot-2 deviation) even though it
  shares the same `pusherr` helper family — that is a distinct
  binding with its own capture.
- No change to `cosmic/sqlite/init.tl`'s call site in this PR; once the
  contract changes, a *separate*, cosmic-side PR simplifies the
  errcode/errmsg juggling at `cosmic/sqlite/init.tl:410-430` — flagged
  here for the goal owner to sequence, not done as part of this
  capture.
