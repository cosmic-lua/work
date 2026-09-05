## Evidence

Two independent duplicate/overlap signals exist today and never talk to
each other:

- `_work/overlap.tl`'s `collisions(id, bodies)` — exact file-path
  collisions: which other open items name the same file under their own
  `## Change` heading. High precision, narrow recall (only fires on a
  literal shared path). Already wired into `_work/gitshow.tl`'s
  `cmd_show` (`show ID`): it builds `bodies` via `store.read_specs` over
  every other open item and prints `overlaps: <handle> on <path>` lines.
- `_work/find.tl`'s `similar`/bm25 text ranking — fuzzy title/spec
  similarity. Higher recall, lower precision — the module's own header
  measures the ratio spread between true duplicates (1.00-0.27) and
  merely-related items (0.21-0.91) as fully overlapping, i.e. no
  threshold on this signal ALONE reliably separates a true duplicate
  from a topically-related item. Wired only into `new`'s pre-mint check
  (`_work/cachequery.similar_lines`), never into `show ID`.

Neither reaches the other: `gitshow.cmd_show` computes `overlaps` but
never queries `find.similar`; `cachequery.similar_lines` never checks
`overlap.collisions`. An item pair that fires BOTH signals — same file
path shared AND similar text — is strong joint evidence of a true
duplicate in exactly the range where the text-similarity ratio alone
cannot decide (a topically-related-but-distinct pair is far less likely
to also share an exact file path by coincidence).

## Change

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

## Non-goals

Changing `SIMILAR_RATIO` or the overlap module's own path-detection
heuristic; extending this correlation to `new`'s pre-mint check (that
check has no `bodies` map of every other item's spec built yet at that
point the way `show ID` does — a separate item if worth doing);
the whole-board periodic sweep (a separate item — this is a per-item
`show ID` enhancement, not a batch scan).
