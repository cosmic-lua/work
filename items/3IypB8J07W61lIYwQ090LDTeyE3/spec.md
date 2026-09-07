## Evidence

`docs/design/nil-flow-sites.tsv` (357 rows, columns `path line class`) and `_build/nil_returns_baseline.tl` (61 lines) are the nil-flow twin of the cast floors, maintained by `_build/nil_returns.tl` (221 lines) and `_build/nil_returns_test.tl` (500 lines, at the cap). Its 7 classes are syntactic POSITIONS a fallible value flows into — `argument` 175, `operand` 90, `return` 44, `assignment` 31, `table-field` 11, `index-key` 3, `the tail` 4 (`docs/design/nil-flow.md:192-324`) — which is exactly what an AST pattern selects: a `T | nil` value as a call argument is `f($$$A, $X, $$$B)` with `$X` a name whose declaration's type admits nil, and so on. The tsv is keyed by `line`, so every edit above a site shifts it (the same defect #1770 fixed for casts).

**Revision note.** The original version of this spec matched the casts
allowlist's FIRST shape: a shrink-only ceiling count per kind, plus a
rule deleting a kind at zero sites. `«bUGM_XojW»` (landed) dropped both
from the casts side — the count is not worth tracking, only whether a
site is classified or justified — and per-cast classification is
already file-local, so the ceiling was the one thing forcing a
whole-tree test to exist at all. This revision builds nil-flow's
allowlist in that already-simplified shape from the start, rather than
building the ceiling and removing it in a second item the way casts
needed two.

## Change

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

## Non-goals

No site is reclassified; no change to the checker's narrowing rules.
No ceiling, no per-kind site count, no zero-site deletion rule — see
Revision note.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`ls _build/*baseline* docs/design/*.tsv _tool/floor.tl` prints
nothing, `.gitattributes` has no `merge=union` line, and
`_build/nil_returns_test.tl` passes with every current site matched
by exactly one kind (no count assertion).
