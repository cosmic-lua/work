Narrow the searched set to what the convention actually promises: the
line above the anchor, the anchor line itself, and the line carrying the
cast's own `as` token. Locate that token in `parsed.tokens` within the
node's span rather than using `span_end`, which is only a proxy for it and
is what admits the surplus.

Add the negative the current suite lacks: a `-- cast:` on a mid-span line
justifies nothing, and an inner cast's reason does not justify the outer
one. Keep every case `«nDWH_QNsm»` added passing — the narrow variant
reaches its whole stated goal, including 24 → 0 on the downstream files.
