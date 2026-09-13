1. One listing for an ambiguous handle: both paths render the candidates as
   handles (`tail.handle(id)`, the form the user typed and the board
   prints), in id order; the template stays `"%s is ambiguous: %s"`.
   `_work/tail_test.tl` and `_work/cachequery_test.tl`'s ambiguity cases
   assert the identical rendering.
2. Delete `tail.resolve` and its tests; if `resolve_glob`'s case-folded
   fallback reuses any of its matching logic, keep that as a private helper.
3. The all-digit test counts `refs.for_each_ref` calls through a module-table
   stub and asserts exactly the exact-glob call, none for the fallback.
