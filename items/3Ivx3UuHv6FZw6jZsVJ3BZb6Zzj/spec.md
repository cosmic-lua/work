## Evidence

Surfaced 2026-09-06 during rework of board item `3IlWcRWI` (handle
«bj12_PZHY», PR #1740) after a fresh-context review's mutation test.
The review's own probe used the length operator on a nilable value:

```teal
local errs = iter:errors()  -- errors(): {string} | nil
print(#errs)
```

This does NOT trigger a type error under `bin/cosmic --check types` /
`--make check`, even against the honestly-retyped `{string} | nil`
signature this PR's rework just landed. Teal's checker does not check
the `#` (length) operator's operand for nilability the way it checks
indexing (`errs[1]`) or a method call (`errs:foo()`) — both of THOSE
mutations, tried on the same value during the rework, were correctly
refused (`cannot index object of type {string} | nil with integer`,
`cannot index key 'upper' in type string | nil`).

Not yet measured: how many other `#<nilable>` sites exist in the tree
today, or whether this is a known upstream tl issue.

## Change (not prescribed — this is a finding, not a worked spec)

Measure the blast radius (a census of `#` applied to a value whose
static type is `T | nil` across `cosmic/**`, the way other honest-nil
work in this tree has done), then decide whether to carry a
`3p/tl/tl_patch/` entry teaching the checker to refuse `#` on a
nilable operand the same way it already refuses indexing/method-calls,
or to file the gap upstream to teal-language/tl first.

## Non-goals

Not a claim that this makes the `bj12_PZHY`/PR #1740 fix incomplete —
every real call site in that PR's diff uses indexing or a method call,
which the checker already catches; this is a general checker gap this
review's probe happened to expose, unrelated to that PR's own
correctness.
