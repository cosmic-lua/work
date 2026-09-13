Changing what `storewrite.save` writes, or any commit shape the board
emits today. Both branches are unreachable, so neither choice can move
a byte of what any current verb produces — a diff that changes an
existing commit's content means the change went wrong.

Deciding the format-5 migration's own design. This item settles whether
`gitwrite` keeps a hook for it, not how the migration works; if the
answer is "keep", naming the migration item is enough.

Auditing the rest of `_work` for other unreachable code. This is one
concrete finding with one concrete decision, not a sweep.
