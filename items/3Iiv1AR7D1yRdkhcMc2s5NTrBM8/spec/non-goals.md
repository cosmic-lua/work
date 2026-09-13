- No change to `cosmic/sqlite/init.tl` or `stmt_cache.tl` in this PR —
  both already work correctly via `db:errmsg()`; once slot 2 carries a
  real string on failure they could simplify, but that's a separate,
  cosmic-side follow-up for the goal owner to sequence, not required
  here.
- No change to the success path's tail-string behavior.
