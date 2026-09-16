First builder stopped on two spec defects, worktree left clean:

- Change 2 named `refs.fetch_prune`/`fetch_refspecs`, which `refresh --execute`
  never calls; the live path is `snapshot_publish.sync` via `fetch_branch_argv`.
- Change 1's fetch-first ordering flips
  `test_missing_configured_tracking_ref_refuses_even_with_fetch_base`: a bare
  `git fetch` recreates a locally deleted but live tracking ref. Resolved in
  the refined spec: with `--fetch-base` that is the intended fetch-then-verify
  outcome, and the refusal applies only without the flag.

Premise confirmed by fixture: never-fetched clone, `claim` without and with
`--fetch-base` both recorded the stale base.