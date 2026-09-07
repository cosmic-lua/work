## Evidence

Every fresh review worktree this session — whether built by hand
(`OiQb_ry43`, `wAe5_evHa`, `9R8e_zA8Q` round 2, `vGr9_mgmX` reviews all
report this) — failed its first test run cold:
`types_gen: cosmo: Failed to open o/3p/cosmos/lua (run 'cosmic --make
fetch')`, because a brand-new `git worktree add` checkout has no `o/3p`
cache. Every reviewer spent one extra `bin/cosmic --make fetch` call
(a network call, ~2s) discovering and fixing this before any real
review work could start. `AGENTS.md` documents the fetch/pin mechanism
generally but not as a "do this first in a fresh review worktree"
checklist item, and neither does the review brief template.

The BUILDER'S worktree doesn't have this problem — `gitboard worktree
ID` bootstraps it with `--make fetch` + `--make build` already run
(confirmed in this session's own `worktree` output: "bootstrapped
cosmic (fetch + build)"). The gap is specific to a review checkout
built ad hoc (by hand today, or by whatever provisions it per
`«review-worktree-unprovisioned»`, unranked, filed alongside this item).

## Change

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

## Non-goals

Not changing the builder worktree bootstrap, which already does this
correctly. Not a general AGENTS.md rewrite of the fetch/pin section —
scoped to the one sentence the review brief is missing.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
