`_build/nil_returns_test.tl` becomes the one file: seven kinds, each
an AST pattern for the flow position (no ceiling count, no per-kind
ceiling field). ONE check: every site the walk finds matches exactly
one kind — a site matching none fails naming `file:line`; a site
matching two names both. No check counts sites, and no check deletes
a kind at zero — a kind reaching zero sites is an editorial decision
about `docs/design/nil-flow.md`'s prose, same as casts, not something
this test enforces. The walk is `_build/nil_returns.tl`'s existing
site finder rewritten over `cosmic.ast` (it reads text today: `grep -c
'match(' _build/nil_returns.tl`); `nil-flow-sites.tsv`,
`nil_returns_baseline.tl`, and the floor half of `nil_returns.tl` go;
`docs/design/nil-flow.md`'s Method section describes the allowlist and
each `### ` class quotes its pattern, without ceiling or shrink
language. With this and the casts item landed, `_tool/floor.tl` has no
reader and is deleted, and D27 is superseded by a record saying no
committed floor remains (the `decide` skill's supersede form).
`_build/nil_returns_test.tl` is at 500 lines: the kinds table and the
one check replace the old ratchet cases, so it shrinks; if not, the
site walk moves to `_build/nil_flow.tl`.

Once this lands, consider folding nil-flow's classification into
whatever check currently gates a fallible-return site the way
`«MsXN_oznh»` folds casts' classification into `--check lint`'s
cast-justify rule — not committed here (nil-flow's site-level gate,
if one exists today beyond this ratchet test, needs its own reading
first), but the same shape applies once this item's simplification is
in.
