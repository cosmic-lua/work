`encode`, the `problems` rules, and every field's semantics are
unchanged — this deletes coercion, not behaviour, except the pinned
wrong-type refusal which was silent data corruption before.
`_work/gh.tl`'s JSON boundary is a separate later slice; do not touch
it.
