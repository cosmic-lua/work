No change to the heuristic's behavior for a session that never sets
`GITBOARD_PRODUCT_ROOT` (the existing `<root>/o/board` convention keeps
working exactly as today, unchanged). No change to what `bin/gitboard`
itself auto-exports.
