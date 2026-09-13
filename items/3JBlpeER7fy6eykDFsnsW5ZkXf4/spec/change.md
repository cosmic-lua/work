A carried patch (`3p/tl/tl_patch/`, per
[D21](docs/decisions/d21-carried-tl-patch.md) — cosmic has no upstream
access to `teal-language/tl` from this environment, so a direct PR
there is not an available first step; note that in the patch entry's
`note` field, and file a corresponding issue in `cosmic-lua/cosmic` if
one doesn't already cover reporting it upstream when access exists)
on the `arity == 1` branch above: when `node.op.op == "-"`, force a
separating space whenever the child's rendered output would otherwise
begin with `-`. `children[1]` is a nested `out`-shaped fragment table
(possibly deeply nested for a chain of unary ops), so "begins with -"
needs to walk to the first actual string fragment, not just check
`children[1][1]` for a bare string — measure the actual shape of a
multiply-nested `out` table for `- - -1` at patch time
(`table.concat`-style traversal, same pattern `add_child` itself
already uses) rather than assuming one level of nesting is enough.
A simpler, always-safe alternative that avoids that traversal
entirely: drop `-` from `tight_op[1]` so EVERY unary minus renders as
`- x` instead of `-x` — correctness over cosmetics, and a real
tradeoff to weigh against the output-style change it causes tree-wide;
decide which at pull time, this item does not prescribe it.
