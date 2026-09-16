`gitboard claim` compares the local target branch only against its
remote-tracking ref as last fetched. In a checkout where nothing has fetched
since the clone — the shape a session harness supplies, where `main` and
`origin/main` are equal and both behind the remote — `stale_target` in
`_work/gitclaim_cli.tl` sees agreement and the claim silently records the
stale base. `--fetch-base` does not help there: `product_base` calls
`fetch_forward` only after the local comparison has already flagged
staleness, so in this shape the flag fetches nothing. Confirm both against
the current tree before editing.

Two changes:

1. In `_work/gitclaim_cli.tl`, when `fetch_base` is true, fetch the target
   branch's configured remote FIRST (the same `git fetch <remote>` that
   `fetch_forward` runs), then run the existing comparison against the
   refreshed tracking ref, then fast-forward exactly as today when the local
   branch is a strict ancestor. Without `--fetch-base` the comparison is
   unchanged; the behind-refusal message and `claim --help`'s `--fetch-base`
   text say that the comparison is against the tracking ref as last fetched,
   and that `refresh --execute` or `--fetch-base` refreshes it.

2. `refresh --execute` (`fetch_prune` and `fetch_refspecs` in `_work/refs.tl`)
   additionally fetches the board remote's default branch into its
   remote-tracking ref (`+refs/heads/<default>:refs/remotes/<remote>/<default>`),
   the default being what `repoprofile.default_base` resolves for the board
   checkout, so a session that starts with `refresh --execute` has a current
   `origin/main` for board-repo items before its first claim. Keep the two
   existing refspecs.

Regressions in `_work/gitclaim_stale_base_test.tl` (a sibling file if it
nears the cap): a fixture with a bare upstream advanced past both the local
`main` and its `origin/main`; a claim without `--fetch-base` records the
local base (the documented limit, asserted so a later change that adds a
network call is deliberate); a claim with `--fetch-base` fetches,
fast-forwards and records the upstream tip; the existing behind-refusal and
missing-upstream cases unchanged. A refresh test asserting `refresh --execute`
updates `refs/remotes/origin/main` in a fixture whose upstream advanced.
