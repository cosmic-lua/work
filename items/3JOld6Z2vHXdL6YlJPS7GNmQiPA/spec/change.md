`cosmic --find` throws a Lua error instead of refusing when the pattern parses
to no statement — an empty pattern, a whitespace-only pattern, or a
comment-only pattern such as `--`:

    cosmic --find ''
    /home/user/cosmic/o/bootstrap/cosmic: /zip/_cli/find.lua:99: attempt to
    concatenate a nil value (local 'compile_err')

The defect is a fallible-return contract violation in
`compile_pattern` (`cosmic/ast/match.tl`). For these inputs
`node_mod.parse(desugared, "<pattern>")` SUCCEEDS — an empty chunk is valid
source — so `parsed` is truthy and the function takes its success branch,
returning `attach_predicates(parsed.node[1], last_predicates)` where
`parsed.node[1]` is nil. It therefore returns `nil, nil`: slot 1 nil with no
message in slot 2.

`_cli/find.tl`'s `run` then does `io.write("find: refused: " .. compile_err)`
on a nil, which throws.

This breaks the honest-nil rule in AGENTS.md — a fallible value is
`T | nil, string`, and a nil slot 1 obliges a string in slot 2 — and it throws
from a path that has a caller, which is not one of D30's three permitted
boundaries.

Fix it in `compile_pattern`: when the parse succeeds but yields no statement
to match on, return `nil` with a message saying the pattern is empty. The
existing refusal path in `run` then renders it correctly with no change:

    find: refused: <pattern>: no expression to match

Harden the caller too, so a future contract slip degrades to a refusal rather
than a crash: `run` should treat a nil message as a generic refusal string
instead of concatenating it.

Regression: extend `_cli/find_test.tl` with the three inputs above, asserting
exit code 2 and a `find: refused:` line, not a throw. Add a case to
`cosmic/ast`'s own tests asserting `compile_pattern("")` returns nil with a
non-empty string in slot 2.
