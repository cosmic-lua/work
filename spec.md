## Evidence

**Correction, 2026-09-06, to this item's own original Evidence**: the
claim that `zs1K_cWnY`'s `repo` field was already explicitly set to
`cosmic-lua/cosmic` at the time `brief` misfired was wrong. Direct
inspection of the item's raw stored `meta` blob, at every commit up to
and including the `take` that claimed it —

    $ git -C <board checkout> cat-file -p <new-commit>:meta
    title: casts: land searcher_test.tl's cast removal once the declining-searcher patch is pinned
    parent: 3HyRcW05wBip6Wqcz145bUQBTyj
    $ git -C <board checkout> cat-file -p <attach-commit>:meta
    title: ...
    parent: 3IvLo8epYDMewqKisHtfnNclCyL
    $ git -C <board checkout> cat-file -p <take-commit>:meta
    title: ...
    parent: 3IvLo8epYDMewqKisHtfnNclCyL
    claim: build-zs1K_cWnY-420d657f
    builders: build-zs1K_cWnY-420d657f

— shows NO `repo:` field was ever stored, at creation, after `attach`,
or after `take`. Yet `gitboard show zs1K_cWnY` printed `repo:
cosmic-lua/cosmic` at every point up through the claim. `show` is
therefore INFERRING an effective repo for display (most likely walking
the parent chain — this item's container, and the census container
above it, both carry `repo: cosmic-lua/cosmic`) rather than reading a
stored field — and that inference is real work `brief` and `take --pr`
do NOT do:

- `brief builder` emitted "Open a PR ... in `cosmic-lua/work`" (the
  board's own default fallback for an unset field, not an inheritance
  walk).
- `take zs1K_cWnY --pr 1741` (the PR actually opened, against
  `cosmic-lua/cosmic`) was flatly REFUSED: `cannot read PR #1741: GET
  /repos/cosmic-lua/work/pulls/1741: HTTP 404: Not Found` — the same
  wrong-repo default, this time blocking a real state-recording
  operation, not just misleading brief text. Fixed only by `gitboard
  set zs1K_cWnY --repo cosmic-lua/cosmic` (an explicit, stored value),
  after which `take --pr` succeeded immediately against the correct
  repo.

So the bug is worse than originally filed: it is not that `brief`
ignores an explicitly-set `it.repo` — it's that NEITHER `brief` nor
`take --pr` do the parent-chain inheritance `show` performs for
display, both instead defaulting silently to the board's own origin
when the item's own field is blank. `show`'s own output cannot be
trusted as ground truth for what `brief`/`take` will actually target —
an orchestrator reading `show`'s `repo:` line and trusting it (as this
session originally did) will be wrong in exactly the cases where it
matters (an item that inherited its repo rather than having it set
directly).

This item's original repro is still valid evidence that a
correctly-inherited-and-DISPLAYED repo does not mean a correctly
STORED one — that distinction is the actual bug, and is what a fix
needs to close: either `show` should stop implying a value is stored
when it isn't (e.g. mark an inherited repo visibly as inherited), or
`brief`/`take --pr` should perform the same inheritance `show` does,
or (matching `HlNE_YWL2`'s stricter design) inheritance should be
resolved and WRITTEN to the item explicitly at `attach`/`new --parent`
time so there is only ever one source of truth to read from.

## Change

Left for refinement — the fix depends on a design choice this item's
evidence does not settle by itself, and it overlaps `HlNE_YWL2`'s
scope (that item's `Change` already proposes requiring `repo`/`base`
non-empty at `new --parent`/`attach` time and removing `brief`'s guess
fallback; if it lands first, an item can no longer reach `brief`/`take`
with an unset `repo` at all, which would close this gap as a
byproduct). Whoever refines this item should first check whether
`HlNE_YWL2` has landed and, if so, verify directly whether this
symptom still reproduces before writing a `Change` — it may already be
fixed by that item alone. If `HlNE_YWL2` has NOT landed, the narrower,
faster fix is: make `show`'s displayed `repo:`/`base:` line and
`brief`/`take --pr`'s resolution use the exact same function, so the
two can never disagree — whichever behavior (inherit vs. refuse) that
shared function implements, `show` and `brief`/`take` would then agree
about it.

## Non-goals

Not re-litigating `HlNE_YWL2`'s own design (require explicit repo/base
at attach time vs. resolve-by-inheritance) — that decision belongs to
that item, already under refinement. Worth checking, once `HlNE_YWL2`
lands, that its own test suite covers an item that gained its parent
via `attach` (the exact path this repro took), not only `new --parent`
— its own Evidence section describes both paths but this repro is a
concrete `attach` case to check against once it ships.
