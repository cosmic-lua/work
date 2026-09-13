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
