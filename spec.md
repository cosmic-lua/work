## Evidence

`_work/overlap.tl`'s `paths_named` tests each token with a bare
`fs.is_present(token)` — a relative path resolved against the RUNNING
PROCESS's working directory, not against any checkout of the item's
repository.

That is the same defect class `«66ad_YWIV»` fixed for the spec bar's
headroom lines (`3ae434f7`, #136) and `«WsH8_pWpE»` fixed for the review
brief (PR #149). Both of those went through `_work.repository_map`;
`paths_named` never did, so the collision half of the module still
answers from wherever the tool happens to be run.

`«WsH8_pWpE»`'s PR body claims "every `repository_map.resolve` caller
already resolved through the map and needed no change". That is true of
the callers it enumerated, but it leaves this one standing: after that
change, "every caller gets the same corrected answer" is still not
literally true of `_work/overlap.tl`.

The user-visible effect is a wrong overlap verdict — two items reported
as touching the same file, or not, based on a directory neither of them
names. Unlike the headroom lines, a collision answer is not labelled with
its evidence, so there is nothing in the output to make the mistake
visible.

Reported by `«WsH8_pWpE»`'s reviewer, outside that item's stated scope.

## Change

Resolve `paths_named`'s relative tokens the way the headroom lines now
do: against a checkout of the item's own repository, at a known commit
rather than a working tree. Where the two need the same resolution, share
it rather than writing it a second time.

When no checkout of the item's repo is available, the collision check
must degrade honestly — say it could not be checked, the way
`not checked:` already does for headroom — rather than silently answering
from the running directory.

Add cases: a token present in the item's repo but absent from the running
directory is found, and the reverse is not; and an item whose repo has no
local checkout reports the degraded answer rather than a confident one.

## Non-goals

Not changing what counts as a path token (`looks_like_path`), not
changing how collisions are ranked or reported once detected, and not
touching the headroom lines. Not making the check reach the network.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
