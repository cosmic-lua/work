1. `_work/gitshow.tl`'s `cmd_show`: alongside the existing
   `overlap.lines(it.id, bodies)` call, also run a `find`-backed
   similarity query over the same `bodies` map (or via the persistent
   cache, matching whichever access pattern `_work.cache` already
   prefers for a read verb) — `show ID` already reads every other open
   item's spec for the overlap check, so the marginal cost is one more
   FTS query, not a new whole-board read.
2. Where both signals name the SAME other item id, render a single,
   distinguished line (e.g. `likely duplicate: <handle> — shares
   <path> AND similar text (ratio N)`) instead of two separate,
   uncorrelated lines a reader has to notice both of and connect by eye.
   Where only one signal fires, keep today's existing separate lines
   exactly as they render now — this item adds a correlation, it does
   not remove either standalone signal.
3. Tests: a `gitshow_test.tl` case with two items sharing both a file
   path and near-identical spec text, asserting the combined line
   renders; a case with only one signal firing, asserting the existing
   single-signal line is unchanged.
