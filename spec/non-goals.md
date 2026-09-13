- Not a `cosmic.http` (Lua layer) bug in isolation — the merge already
  happens before that layer sees the headers. A local Lua workaround
  that re-scans raw head bytes is explicitly discouraged above in favor
  of fixing the one authoritative parse.
- Not scoped to fix every non-repeatable header's duplicate handling —
  start with `Content-Length` (the one with a documented RFC MUST and
  real smuggling consequence); a broader audit is separate.
