`_cli/build/work.tl` (or the make rule it emits for a test with a
`reads:` header): make the test's prerequisite for a `reads:` tree a
stamp derived from the tree's LISTING (sorted paths, regenerated
cheaply on every run via an order-only or always-run rule) rather
than the files' mtimes alone, so a rename, add or delete inside the
tree changes the stamp and schedules the recipe. Add a test in
`_make/` or `_cli/build/` that renames a fixture input on a warm
tree and asserts the test re-runs. Measure the cost on a full
`--make test` and record it in the PR body.
