Re-run the census's Method (`docs/design/nil-flow.md`, `## Method`) to
get the current site list, and take every row whose path is NOT under
`cosmic/`. For each, wrap the producing call in `check.must` so the
local is a plain `T`:

```teal
local res = testrun.run(paths)
->
local res = check.must(testrun.run(paths))
```

Add `local check = require("cosmic.check")` where a file does not
already import it. `check.must` declares ONE return, so it composes in
argument and `for` positions without parenthesis-truncation.

A site where `check.must` is wrong — a test that DELIBERATELY exercises
the nil branch, or one asserting on the error string — keeps its
current shape and gets an explicit guard instead. Name every such site
in the PR, with the reason.

Headroom in the files most likely to gain a `require` line, measured
2026-08-26 (`wc -l`, against the 500-line cap): `_fuzz/literal_fuzz_test.tl`
466, `_make/pin_test.tl` 458, `_tool/doc/index_test.tl` 432,
`_tool/example_test.tl` 369, `_perf/gate_test.tl` 366,
`_make/graph_test.tl` 361. A wrap is an in-place edit, so the only
growth is at most one `require` line per file.

`grep -c 'check\.must(' <file>` over the 13 candidate files totals
**91** today (2026-08-26).
