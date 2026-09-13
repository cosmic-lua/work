`brief review ID`'s "Where to work"/checkout section: state explicitly
that a freshly built review worktree needs `bin/cosmic --make fetch`
(and, if running any test, `--make build` once) before tests will run
— the same one-line note a builder brief doesn't need because
`worktree ID` already did it. If `«review-worktree-unprovisioned»`
lands first (a `worktree ID --review`-style command bootstrapping the
review checkout with fetch+build already run, mirroring the builder
path), this item folds into stating that instead — either way, a
reviewer's first test run should not have to discover the missing pin
cache itself.
