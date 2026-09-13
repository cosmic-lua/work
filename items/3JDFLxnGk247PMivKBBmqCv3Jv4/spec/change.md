In `_work/fixture.tl`, trim the comment above `git()`'s retry logic to
state the mechanism and rationale only (what failure it retries and why,
without the specific PR numbers, CI run/job IDs, or timestamps — those
stay in the board item's history, not the source).

In `_work/fixture_test.tl`, add one more case: stub `child.run` to return
the locked-file failure text on every attempt (exhausting
`WORKTREE_ADD_RETRIES`), and assert the retry loop gives up and surfaces
the original loud failure exactly as before this feature existed (same
error text, no swallowed failure, no infinite retry).
