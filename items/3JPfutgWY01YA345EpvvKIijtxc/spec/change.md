The current _work/brief.tl already derives the no-receipt builder worktree
path from the item's claim and repository mapping, filling it when the
directory exists. Preserve that behavior. Strengthen the existing regression
in _work/brief_rework_test.tl rather than adding a second derivation path.

For the positive builder case, create its actual claim-named worktree and
advance its HEAD with an empty commit to model resumed work. Emit the builder
brief without a receipt and assert the exact worktree path, no <WORKTREE>
placeholder, and the closing verdict containing "nothing left to fill".

For the missing-directory case, establish a real mapped claim but do not
create its derived worktree. Assert that the directory is absent and that
the emitted brief and closing verdict retain the <WORKTREE> placeholder.
The existing negative case has no claim, so it does not yet exercise this
claimed-but-missing condition.

Run the focused brief regression and preserve receipt validation tests.
For mutation evidence, suppress derivation for the no-receipt builder case
in a temporary source mutation, require the named positive regression to
fail, then restore source and generated output exactly.
