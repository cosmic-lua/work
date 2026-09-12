## Evidence

PR #123 (board item `f6YD_gyJi`) fixed a real git-auto-maintenance race in
the coverage stage's shared-template fixtures by setting `git config
maintenance.auto false` (client repos) / `receive.autogc false` (bare
"remote" repos) immediately after creation in `_work/commit_flow_fixture.tl`,
`_work/fixture.tl`, `_work/store_test.tl`, `_work/storewrite_test.tl`, and
`_work/storeref_test.tl`.

`_work/storeref_processcount_test.tl:34-45` has the identical shape —
`store.init_repo(state_template)` then `fs.copy_tree` per test case — and
its own header states it was split out of `_work/storeref_test.tl`, one
of the five files that DID get the defensive treatment. This file was
missed. Today it is not actually exposed to the race (`store.init_repo`'s
commit goes through git plumbing — `commit-tree`/`update-ref` — which PR
#123's own investigation confirmed never triggers `run_auto_maintenance`),
so this is not a live bug. But the same "disable it anyway at zero cost,
so a future change to this write path can't silently reopen the race"
reasoning PR #123 applied to its four siblings was not applied here,
leaving one inconsistent, unguarded copy of the same pattern.

## Change

Add the same guard to `_work/storeref_processcount_test.tl`'s template
setup: `git config maintenance.auto false` on the template repo
immediately after `store.init_repo`/`git init`, before any commit,
matching the exact placement and reasoning in the four sibling files PR
#123 already patched (read that PR's diff for the precise pattern to
copy — same repo, same commit).

## Non-goals

Not re-investigating whether this file is currently exposed to the race
(PR #123 already established it is not, via plumbing-only commits) —
this is purely closing the one inconsistent copy of an already-decided
defensive pattern, at the same "zero measurable cost" PR #123 itself
used to justify applying it to files not currently exposed either.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
