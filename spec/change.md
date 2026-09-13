A design decision this item settles, then builds:

1. **Where it runs.** `gitfsck.tl`'s own header scopes it explicitly to
   structural corruption ("an item's tree not re-encoding...", dangling
   edges, decode problems) — a content-overlap finding is a different
   KIND of fact, not a structural defect, so bolting it onto `fsck`
   would blur that scope. Options: a new verb (`gitboard dupes`, read-
   only, `gitboard-dupes:` verdict line, following every other read
   verb's convention); or folding into bare `show` (no id) as a new
   board-health section alongside its existing `graph:` problem lines.
   Pick one and say why.
2. For each open item (title + spec, per «XSDr_DioY»
   once it lands — reuse its combined-query shape rather than
   duplicating it), run `find.similar` against the whole table, keep
   hits above `SIMILAR_RATIO` (or a separately-tuned threshold — this
   sweep's false-positive cost is a person reading one extra line, not
   a refused mutation, so it can afford to be a little louder than the
   pre-mint check), and deduplicate symmetric pairs (A~B and B~A are one
   finding).
3. Cross-reference `overlap.collisions` the same way «z28g_jVQw» does
   for `show ID`, so a whole-board
   cluster report distinguishes "shares a file path and similar text"
   from "similar text only."
4. Report format: one line per cluster (2+ items), each member's handle
   and title, so a session can `gitboard show`/compare/end without
   re-deriving which items are involved.
5. Tests: a small fixture board with a planted duplicate pair and an
   unrelated pair, asserting the sweep finds the former and not the
   latter.
