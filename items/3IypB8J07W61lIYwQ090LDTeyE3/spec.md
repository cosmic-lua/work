## Evidence

`docs/design/nil-flow-sites.tsv` (357 rows, columns `path line class`) and `_build/nil_returns_baseline.tl` (61 lines) are the nil-flow twin of the cast floors, maintained by `_build/nil_returns.tl` (221 lines) and `_build/nil_returns_test.tl` (500 lines, at the cap). Its 7 classes are syntactic POSITIONS a fallible value flows into — `argument` 175, `operand` 90, `return` 44, `assignment` 31, `table-field` 11, `index-key` 3, `the tail` 4 (`docs/design/nil-flow.md:192-324`) — which is exactly what an AST pattern selects: a `T | nil` value as a call argument is `f($$$A, $X, $$$B)` with `$X` a name whose declaration's type admits nil, and so on. The tsv is keyed by `line`, so every edit above a site shifts it (the same defect #1770 fixed for casts).

## Change

`_build/nil_returns_test.tl` becomes the one file, the same shape as «casts allowlist»: seven kinds, each an AST pattern for the flow position plus the count of sites it may match today; every site the walk finds matches exactly one kind, no kind exceeds its count, a kind at 0 is deleted. The walk is `_build/nil_returns.tl`'s existing site finder rewritten over `cosmic.ast` (it reads text today: `grep -c 'match(' _build/nil_returns.tl`); `nil-flow-sites.tsv`, `nil_returns_baseline.tl`, and the floor half of `nil_returns.tl` go; `docs/design/nil-flow.md`'s Method section describes the allowlist and each `### ` class quotes its pattern. With this and the casts item landed, `_tool/floor.tl` has no reader and is deleted, and D27 is superseded by a record saying no committed floor remains (the `decide` skill's supersede form). `_build/nil_returns_test.tl` is at 500 lines: the kinds table and the three checks replace the old ratchet cases, so it shrinks; if not, the site walk moves to `_build/nil_flow.tl`.

## Non-goals

No site is reclassified; no change to the checker's narrowing rules.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`ls _build/*baseline* docs/design/*.tsv _tool/floor.tl` prints nothing, `.gitattributes` has no `merge=union` line, and both allowlist tests pass with their kinds summing to the tree's site counts.
