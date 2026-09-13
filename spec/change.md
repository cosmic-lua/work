`gitboard new TITLE --parent ID` without `--repo` files an item whose
`meta` has no `repo:` line, while `help new` promises `--repo OWNER/NAME
the repo its PR lands in; default is the board's origin` (`grep -n "default
is the board's origin" _work/gitcommands.tl`). Observed 2026-09-13: fourteen
items filed under «yDA5_DbKm» that way carried no repo, `worktree`
refused each with `has no repo set — worktree needs one to resolve a
checkout`, and `claim --fetch-base` on one of them leased against the
item's own ref tip (claim base = the item commit, branch checked out to
`meta`/`spec`) instead of refusing. Two fixes, one mechanism each: (1) in
`new`'s dispatch (`grep -n "cmd_new" _work/gitverbs.tl`), when `--repo` is
absent inherit the parent's `repo` and `base` (an outcome under the board
inherits the board's origin, `_work/gitowner.tl`'s notion of the board's
repository — cite the function you use), so the help line is true; (2)
`claim` (`grep -n "local function cmd_claim" _work/gitclaim_cli.tl`)
refuses an item with no `repo` by name — `«h» has no repo; set one before
claiming` — rather than resolving a product base against the board
itself. Regression tests for both: an item filed under a parent with a
repo carries that repo; `claim` on a repo-less item is refused with that
message and prepares nothing.
