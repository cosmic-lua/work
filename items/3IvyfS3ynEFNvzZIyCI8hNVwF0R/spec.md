## Evidence

`show`'s board-overview pullable count and `next`'s single
recommendation can go stale relative to the live board immediately
after a `spec` write that newly clears an item's bar — `take ID` on
the same item succeeds even while `show`/`next` still report it as
missing the bar. The staleness itself, and a candidate root cause in
`_work/gitview.tl`'s digest-gated cache, is tracked as its own item,
«Vahb_Krg9» (gitboard: show/next's pullable count and next's
recommendation go stale after a spec write clears the bar) — this item
is not that fix. This item is the interim workaround, which nothing in
`gitboard help orchestrate` or `help bar` currently states, and which
has independently cost real time across (at least) three sessions
while the underlying cache bug remains unfixed:

- the pass that originally surfaced «Vahb_Krg9» (2026-09-05, `mEBx_YKCA`):
  refined a spec, confirmed via `show` that the item's own `bar:` line
  cleared, yet the board overview stayed at `todo 202 (0 pullable)` and
  `next` kept recommending a different item — resolved only by trying
  `take mEBx_YKCA` directly.
- «saSF_vgis» (friction: 2026-09-05 work9c, item `sTmy_8tBZ`): spent
  ~25 tool calls independently re-deriving `ready_gaps`/`is_ranked`
  against the item's raw `spec.md` (via `git cat-file`) to confirm the
  item genuinely had zero gaps, before trying `take` directly as a
  probe — which succeeded immediately. The pass's own retrospective:
  `bin/gitboard find "pullable"` (which surfaces «Vahb_Krg9» itself,
  already describing this exact shape) was tried LAST instead of
  first.
- the prior, now-closed friction log `3IuEiG30` (friction: 2026-09-05
  work9) recorded the identical `show`/`next` vs. `take` disagreement
  and explicitly declined to file it pending a second repro — which
  arrived as «Vahb_Krg9» itself.

## Change

`gitboard help orchestrate` (and/or `help bar`, wherever the pull step
is described): add one explicit statement — after writing a `spec`
that should newly clear an item's bar, verify with `take ID` directly
rather than trusting `show`'s board-overview pullable count or `next`'s
single recommendation, both of which can be stale relative to the live
board until «Vahb_Krg9» lands. Cross-reference «Vahb_Krg9» by id in the
added text so the workaround note and its root cause stay linked, and
so the note is easy to remove once that item ships a real fix.

## Non-goals

Not a fix for the staleness itself — that is «Vahb_Krg9», unchanged by
this item. Not a change to `next`'s or `show`'s output shape (a richer
fix, e.g. having `next` self-verify with `take --dry-run` before
recommending, is out of scope here and would duplicate «Vahb_Krg9»'s
own remit). This item is text-only, in `gitboard`'s own help output.
