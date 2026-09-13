- No change to what a migrated item contains; batches and the single
  push produce the same trees (only the commit dates differ per batch).
- No retry or splitting inside `migrate --execute`: the caller picks the
  batch size, because the limit is the caller's proxy, not the board's.
- Not the retire item: `06-retire` still deletes this module in full.
