In `cosmic/format/types.tl` (354 lines today, `wc -l` → 146 headroom
under the 500 cap), `mark_return_list` marks a function type's return
list "to the end of the line", so a CODE keyword after the list is
claimed as type: in `if x is function(): any then` the `then` is
marked, never counts as a block opener, and the guard body dedents —
reproduced 2026-08-27 with `o/bin/cosmic --format` on that shape (body
lands at the `if`'s own column, the trailing `end` and following line
pulled a level left; output is its own fixpoint so `--make fmt`
passes). Fix: in `mark_return_list`, at depth 0, stop (return before
marking) on any `kind == "keyword"` token other than `nil` and
`function` — the only keywords legal inside a return list
(`function(): any | nil`, `function(): function(): any`). The stop
covers `then`, `do`, `and`, `or` and the rest by construction, and the
shared helper also serves `mark_carried_type`, so the wrapped-type
variant inherits the fix.

Add regression tests in `cosmic/format/types_test.tl` (335 lines,
`wc -l` → 165 headroom), house style `assert_format(src, src, ...)`:
the if-guard shape (`if x is function(): any then` with an indented
body) formats to itself; the `while ... is function(): any do` shape;
and `function(): any | nil` in an if-guard still formats to itself
(the `nil` exemption).
