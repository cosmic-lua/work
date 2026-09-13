Four narrowing behaviours, added as edit keys in
`3p/tl/tl_patch.tl` beside the five that are there
(`narrow-assert-decl`, `narrow-truthiness`, `narrow-and-operand`,
`narrow-assert`, `narrow-eq-nil`), applied by `_make/patch.tl` against
the pinned `tl` 0.24.8. Each edit needs its `-tl-tl` twin if it lands
in code that `tl.tl` also carries, and each anchor must match exactly
once.

1. **A branch that cannot fall through terminates, not just `return`.**
   `if not x then break end` must narrow `x` after the guard, as
   `return` already does. Same for `goto <label>`, `error(...)` and
   `os.exit(...)`. 25 census sites; `_docs/publish.tl` 4,
   `cosmic/fs/tree.tl` 2.
2. **`a or b` is non-nil when `b` is.** `fs.read(p) or ""` must type as
   `string`, not `string | nil`. 55 sites; `_tool/testrun_test.tl` 8,
   `cosmic/codec_test.tl` 6. Leave the both-operands-are-unions case
   (`out or qerr`) alone: it stays a union, correctly.
3. **A disjunctive guard distributes.** `if x == nil or x == "" then
   return end` must narrow `x` in the fall-through branch, because
   every arm of an `or` guard is false there. 12 sites.
4. **`and`-operand argument position.** `narrow-and-operand` already
   narrows `x and x.field` and `x and #x`; extend it to the whole right
   operand, so `x and f(x)` narrows too. 8 sites.

Then delete the four probe programs' worth of doctrine that described
these as gaps, and add one test per behaviour to
`cosmic/teal_narrowing_test.tl` alongside the existing narrowing tests.
