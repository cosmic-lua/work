1. `_make/imports.tl` — make the `reads:` grammar multi-token, matching the
   `--- env:` grammar #1156 introduces: `reads_scan` matches
   `^%-%-%- reads: (.+)$` and splits the capture on whitespace; each token is a
   declared path. `reads_of_file` keeps its existing per-path behavior (expand
   directories, refuse a missing path loudly) over every token.
2. `_make/imports_test.tl` — regression cases: a multi-path declaration yields
   every path; a single-path declaration is unchanged; a declaration with one
   missing path among several still refuses naming it. The invariant in words:
   a multi-path declaration must either parse fully or refuse loudly, never
   no-op.
3. `_make/graph_test.tl` — extend `test_project_mk_carries_declared_reads`
   (currently `:326-352`) with a two-path declaration landing both paths in
   `deps_<stem>`.
4. No change to `_build/env_vars_test.tl` — its existing eleven-token line
   (`env_vars_test.tl:2`) becomes live by this fix alone; the acceptance below
   proves it.
