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
