## Evidence

Directed-graph reachability is implemented independently in two places in
this ecosystem, and a third consumer is on the way:

- cosmic-lua/work `_work/priority.tl` (2026-09-05): `walk` (line 91, DFS
  over `beats` edges), `dominated` (110, the transitive closure of one
  node; the node reaching itself IS the cycle test), `cycle_problems`
  (399), `edge_refusal` (424 — "would this new edge close a cycle several
  comparisons built"), and `_work/flow.tl`'s `waits_on` (285, reachability
  over `blocked_by`) and `root_of` (309, walk parents to the top).
- cosmic's own `_make/deps.tl` `closure` (line 114): the transitive import
  closure of one file, the same DFS, written again for the build graph.
- «KYPX_s06P»'s events table walks first-parent chains from ref tips —
  reachability once more, over commits.

None of them is hard, which is exactly why each was written in place; the
cost is that `priority.tl` (478 lines) and `flow.tl` (490) both sit near
the cap carrying graph code that has nothing to do with boards. `cosmic
--docs graph` finds nothing (2026-09-05); `cosmic.deep` matches "cycle"
only for reference cycles in deep comparison.

## Change

1. `cosmic/graph.tl`: a small pure module over an adjacency map
   `{string: {string}}` (node id -> out-neighbours; a neighbour absent
   from the map is ignored, the way `priority.walk` ignores an id with no
   item): `reach(g, id) -> {string: boolean}` (transitive closure of one
   node), `closure(g) -> {string: {string: boolean}}` (all nodes),
   `has_cycle(g) -> boolean`, `cycles(g) -> {{string}}` (one
   representative cycle per strongly connected component, for reporting),
   `would_cycle(g, from, to) -> boolean` (the `edge_refusal` core),
   `roots(g, parent_of)` or an equivalent `ancestors(g, id)` for the
   parent-chain walk, and `toposort(g) -> {string} | nil, {string}` (nil
   with the cycle when one exists) since `_make` needs it.
2. Iterative, not recursive: `priority.walk` recurses and a deep chain
   would hit the Lua C-stack limit; the port uses an explicit stack.
3. Tests: closure/cycle cases ported from `_work/priority_test.tl`, plus
   a 100k-node chain proving the iterative walk.
4. `_make/deps.tl`'s `closure` is re-expressed over `cosmic.graph` in the
   same PR (it is the in-tree consumer that proves the API).

## Non-goals

Porting `band`/`own`/`positions` — those are gitboard's priority
semantics, not graph theory; the work-side port of `priority.tl`/`flow.tl`
onto this module (its own follow-up after a release carries it).
