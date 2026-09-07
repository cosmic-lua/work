## Evidence

`gitboard show ZD1x_zeG6` (repo cosmic-lua/work) prints `absent: `_work/gitshow.tl` does not exist in the tree`, yet `/home/user/work/_work/gitshow.tl` is 351 lines on main. The spec-bar check that verifies paths named in a spec resolves them against the checkout the tool runs in (cosmic-lua/cosmic, where no `_work/` exists), not the item's own `repo`. Every work-repo item's spec therefore carries a false `absent:` flag when shown from a cosmic checkout — «7Vds_BXrP» showed one for a file that genuinely did not exist, indistinguishable from this false positive — and the flag is the same text a refiner uses to decide a spec is stale.

## Change

The bar's path check resolves a spec's backticked paths against the item's `repo`: the sibling or `o/` checkout `gitboard worktree` already locates for that repo (its `resolve_checkout`), falling back to "not checked (no checkout of REPO here)" — never to `absent` — when none is found. Test: an item with `repo` set to the other repository and a spec naming a file that exists only there shows no `absent:` line.

## Non-goals

No network lookup; no change to the other bar rules.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard show ZD1x_zeG6` run from a cosmic checkout beside a work checkout prints no `absent:` line for `_work/gitshow.tl`.
