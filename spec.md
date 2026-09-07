## Evidence

PR cosmic#1777's reviewer mutated `cosmic/ast/rewrite.tl`'s `""`-deletion branch to delete only the node's own byte span instead of the statement's line range, and `test_rewrite_deletes_a_call_statement_leaving_no_blank_line` (`cosmic/ast/rewrite_test.tl:80`) stayed green: `rewrite()` pipes its output through `cosmic.format.format` (`rewrite.tl:323`), which normalizes the stray blank line away, so the test cannot tell the two deletions apart. Only the adjacent comment-refusal test caught the mutation. The test's name promises a guard it does not hold alone.

## Change

`cosmic/ast/rewrite_test.tl`: the no-blank-line case asserts the PRE-format splice (call the internal splice/line-range step the module exposes, or assert on the unformatted result if `rewrite` returns it — read the module first), so a byte-span-only deletion fails it on its own; or, if the module exposes no pre-format seam, rename the test to what it does prove and add a `line_range` unit case on the helper directly. Mutating the branch to byte-span deletion must fail the case.

## Non-goals

No change to `rewrite()`'s behaviour or its formatting step.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

The byte-span mutation described above fails a test in `cosmic/ast/rewrite_test.tl` whose name says it guards line-range deletion.
