## Evidence

Two non-blocking findings from `IXiQ_JbjO`'s review (commit
`a0061ad13acafbce3d607986916d766d01b31f00`, landed as `4f48ed42`), held
back from that item's rework so the repair stayed scoped to its two
blocking findings.

**The already-merged guard was dropped.** Before "Redesign gitboard around
caller-owned Git transport" (`ae840934`), `verdict accept` refused the
landing outright when the request was already merged or closed —
`review.blocks_accept(p)` (`git show ae840934^:_work/gitverdict.tl`, around
lines 252-257). `_work/ghland.tl` does not carry that check, so an
already-merged pull request now gets a merge `PUT` that fails, and the
verdict line prints `landing failed (...), land it by hand` about work that
has in fact already landed. That is a behaviour change the item's spec never
named, and the message actively misleads.

**`ghland.pull_of` is exported with no caller and no direct test.**
`_work/ghland.tl` exports it on the module record, but nothing outside the
module calls it, and the malformed/non-GitHub-URL branch its own doc comment
advertises is covered only incidentally, through the empty-URL case. A
reviewer probe found the parse is loose in ways nothing pins: `.../pull/7abc`
parses as 7. Host spoofing is correctly rejected today (`github.com.evil.test`,
a bare `http://`, `gitlab.com`), and `.../pull/0` and a 20-digit number both
fall through cleanly without crashing — but none of that is asserted
anywhere, so it is all free to regress silently.

## Change

Restore the already-merged guard: before attempting a landing,
`_work/ghland.tl` reads the request and returns a distinct, accurate result
when it is already merged or closed — the verdict line should say the work
already landed, not that landing failed and the caller should do it by hand.
Add a case covering an already-merged request.

Then settle `pull_of`: either give it direct tests covering the branches its
doc comment claims (a non-GitHub host, a malformed tail, a missing number)
and keep it exported, or drop it from the module record and leave it local.
Prefer testing it — the parse is the thing that decides which repository a
live merge is aimed at, so its edges deserve pins rather than removal.

## Non-goals

Not revisiting the two blocking findings from that review — the repo-identity
fix and the 409 fallback are that item's own rework. Not widening
`_work/ghland.tl`'s responsibilities beyond the landing step.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
