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
