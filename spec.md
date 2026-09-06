## Evidence

A test that reads a file at runtime rather than `require`-ing it is
invisible to the runner's staleness check, so editing that file does
not re-run the test and a recorded pass is reused. The declaration
that fixes it exists — `git grep -n -- '--- reads:' -- _build cosmic`
shows `_build/doc_symbols_test.tl` declaring its doc-index input, and
`_build/cast_sites_test.tl`/`_cli/reads_lint.tl` treat `reads:` as a
pre-graph input line — but AGENTS.md's Testing section
(`grep -n '## Testing' AGENTS.md`) never names it. The J0zb_occu
builder (PR 1764, 2026-09-06) lost ~6 calls and ended by deleting
`o/<path>.test.*` result caches "by trial rather than documentation";
its test reads `bin/gitboard` with `fs.copy`.

## Change

AGENTS.md, `## Testing`, after the `TEST_TMPDIR` sentence: one
paragraph — "A test that reads a file the graph cannot see (a script
copied with `fs.copy`, a fixture under `testdata/`, a generated index
under `o/`) declares it with a `--- reads: <path>` line in its header,
one path per line; the runner re-records the result when that file
changes. Without the line an edit to the file reuses the last recorded
pass." Quote one existing declaration as the example
(`_build/doc_symbols_test.tl`'s). `_cli/gitboard_root_test.tl` (PR
1764, once merged) gains `--- reads: bin/gitboard`.

## Non-goals

No runner change; no new lint.
