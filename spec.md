## Evidence

Every existing duplicate/overlap signal is triggered per-mutation only:
`new`'s pre-mint check (`_work/cachequery.similar_lines`), and — once
filed — `attach`/`compare`'s widened version of the same check, plus
`show ID`'s per-item overlap+similarity correlation. None of these ever
runs against items that were already on the board before the check
existed, or against a pair neither side ever happened to mint/attach/
compare/show at the right moment to trigger it. This session's own
history is direct evidence the gap is real: multiple genuinely
duplicate/overlapping items surfaced only because a human (or an
orchestrator) happened to read enough of the board by hand to notice
the phrasing was different but the substance was the same — the
"similar:" warning at mint time catches a NEW item against the EXISTING
board, never two existing items against each other after the fact.

The cost of a whole-board pass is smaller than it looks: `find.similar`
is already backed by the FTS5 index (`_work/find.tl`'s `ranked_rows`,
one `MATCH` query per call), so a sweep is O(n) indexed queries — one
`find.similar`-shaped call per open item against the whole table — not
an O(n²) brute-force comparison. At ~920 open+closed items today (per
`gitboard fsck`'s own count), that's on the order of what `fsck` itself
already does in one pass.

## Change

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

## Non-goals

Automatically acting on a found cluster (attaching, blocking, or ending
one as not-planned) — this reports, a session or orchestrator decides;
running as part of `--make ci` or any gate — this is board-content
housekeeping, not a correctness check; changing `SIMILAR_RATIO`'s
existing meaning for the pre-mint check.
