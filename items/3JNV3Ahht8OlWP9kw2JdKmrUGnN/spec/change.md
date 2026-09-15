`gitboard help review` requires every reviewer to mutation-test a guard, and
the obvious mutation lies about one common guard shape. Two reviewers hit it
independently this session, and each briefly concluded a real guard was
decoration.

Both were mutating the `(no repo) sorts last` rule in a `table.sort`
comparator. Both inverted one boolean branch. Both saw the test stay GREEN:
Lua's `table.sort` on a 2-element array calls the comparator once, and the call
order it happens to use can still produce the correct result from a
half-broken comparator. Each then needed a second mutation to get a true
signal.

The second reviewer's own countermeasure, then verified: mutate a comparator by
DELETING the special-case branch, removing the invariant, rather than flipping
its return. A flip can be accidentally consistent on a small fixture; a
deletion cannot.

Add that to the doctrine, in `_work/doctrine.tl`'s `review` page, beside the
existing mutation instruction ("The diff review's own step: mutation-test at
least one guard the change adds"): for a comparator or any guard whose two
branches are symmetric, delete the branch rather than flipping it, because a
flip can leave the ordering accidentally correct and the test green.

`grep -n "mutation-test at least one guard" _work/doctrine.tl` locates the
paragraph.
