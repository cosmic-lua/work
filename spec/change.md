1. Audit which `_tool/*_test.tl` files (and any other file outside
   `_make/**`/`_cli/**`) actually spawn the tree's built `cosmic`
   binary the way `_make/fixtures_test.tl` originally did — re-measure
   the staleness bug per candidate file before fixing it (edit
   `_make/check.tl` trivially, rebuild, run the test twice, check
   `.in`/`.time` mtimes and content — not just `.got`'s mtime, which
   moves universally via `testrun_dep` regardless of whether the test
   actually re-executes; see `3Im3EEyh`'s spec for the confound and how
   to avoid it).
2. For files that do reproduce the bug: prefer widening
   `_make/graph.tl`'s `exercises_the_engine(path)` to also match
   `^_tool/` if that's true for all its test files, over adding
   per-file declarations — the same one-line, positional shape as
   `3IkoLdmJ`'s actual fix, not a per-file `reads:` (which the merged
   fix specifically avoided for the cold-build ordering reason above).
   If `_tool/`'s tests don't uniformly need this (some `_tool/*_test.tl`
   files may not spawn the binary at all), scope the widening precisely
   rather than blanket-including `^_tool/`.
3. Confirm the fix does not over-invalidate an unrelated pure-unit
   test's cached record (same check as `3Im3EEyh`'s reproduction: a
   control file outside the widened scope must show its `.in`/`.time`
   unchanged across an engine rebuild).
