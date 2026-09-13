New patch group file `3p/tl/tl_patch/closure.tl` (narrow.tl is 393
lines — 107 headroom, too little for ~130 lines of entries), entries
named `closure-*`, all `file = "tl.lua"`, no `tl.tl` twin (checker
logic). Anchors verified exact-once against the fetched tl.lua:

1. `closure-root` — after `assert(ast.kind == "statements")` (one
   site, tl.lua:15149), set `self.chunk_body = ast` before
   `recurse_node(self, ast, visit_node, visit_type)`.
2. Seven widen call sites switch to
   `self:widen_all_unions(self.chunk_body)` — nil falls back to
   stock widen-all, so any entrance that skips `closure-root` keeps
   stock behavior:
   - the function-rvalue assignment site (tl.lua:13076,
     `if rval.typename == "function" then`),
   - `local_function` / `local_macroexp` / `global_function` /
     `record_function` `before` (13589/13622/13651/13695, today
     node-less),
   - `["function"]` / `["macroexp"]` `before` (13836/13871, today
     passing the closure's OWN node — the probe8 unsoundness).
   The `["label"]` site keeps its node-less widen-all.

Tests in a NEW `cosmic/teal_closure_test.tl`
(teal_narrowing_test.tl is 485/500 and teal_test.tl 493/500 — no
room), house shape (fs.write to TEST_TMPDIR, teal.check_file,
self-called tests):
- the guarded chunk-level name, never assigned, used in a named
  closure → checks (the coverage-idiom win; refused today);
- the same with `v = pick()` anywhere after the closure → refused
  (assignment-anywhere widens);
- probe8's anonymous shape with reassignment → refused (the stock
  hole closes);
- the escaped-child upvalue counterexample above → refused (the
  scope decision pinned).
