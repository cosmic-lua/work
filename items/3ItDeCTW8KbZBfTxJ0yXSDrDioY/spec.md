## Evidence

`_work/cachequery.tl`'s `similar_lines(root, title)` (lines 80-93) —
`new`'s pre-mint duplicate check — takes only a title:
`find.similar(c, title)`, and `_work/gitgraph.tl:104`'s call site
(`cmd_new`) passes `title` alone even though `spec` (the sidecar text
being filed alongside it) is already in scope at that exact line. So a
new item whose SPEC overlaps heavily with an existing one, but whose
TITLE is phrased differently, is never flagged — exactly the hard case
`_work/find.tl`'s own module header measures: three of four known
duplicate/overlap pairs on the production board were "phrased
differently about the same underlying binding." FTS5's `MATCH` already
searches every indexed column (`title` AND `spec`) unless
column-filtered, so a query seeded from the new item's spec text would
already surface a hit sitting in another item's `spec` column — the gap
is that nothing ever asks that question today.

Two other write paths that could carry the same cheap warning currently
don't at all: `grep -n similar _work/gitgraph.tl` shows it wired only
into `cmd_new`, not `cmd_attach` (line 135); `grep -n similar
_work/gitcompare.tl` shows `cmd_compare` (line 29) has no such call
either. Both mutate the graph the same way `new` does (a triage capture
gaining a parent; a priority edge being recorded) and both are exactly
the moments a session benefits from being told "this looks like X"
before committing to it.

## Change

1. `_work/cachequery.similar_lines`: add an optional `spec_body`
   parameter; when non-empty, run a second `find.similar`-shaped query
   seeded from ITS tokens (not just the title's) and merge/dedupe the
   hit lists before rendering, keeping the existing "at most three,
   infallible by design — a warning, never a refusal" contract exactly
   as documented.
2. `_work/gitgraph.cmd_new` (line 104): pass `spec` (already in scope)
   through to the widened `similar_lines`.
3. `_work/gitgraph.cmd_attach` and `_work/gitcompare.cmd_compare`: call
   `similar_lines` the same way `cmd_new` does — title plus the
   attaching/comparing item's own current spec sidecar (`store.read_spec`)
   — printed as the same non-blocking `similar: <handle> <title>` lines,
   before each verb's own verdict line.
4. Tests: a case in each of `gitgraph_test.tl`/`gitcompare_test.tl`
   asserting the warning lines print (or don't, below threshold) the
   same way `gitgraph_test.tl` already covers for `new`.

## Non-goals

Using this signal to SUGGEST which container an attaching root should
go under (a related but distinct idea — ranking candidate PARENTS by
similarity rather than flagging candidate DUPLICATES — left for a
separate item if it's worth pursuing); changing `SIMILAR_RATIO` or any
other ranking constant; the cross-referencing of this signal with
`overlap.tl`'s file-collision detection (a separate item, «to be
cross-referenced by handle once filed»); a whole-board sweep (also
separate — this item is only about the three per-mutation call sites).
