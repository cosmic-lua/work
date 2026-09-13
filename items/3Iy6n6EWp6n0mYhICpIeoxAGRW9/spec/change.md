AGENTS.md, `## Testing`, after the `TEST_TMPDIR` sentence: one
paragraph — "A test that reads a file the graph cannot see (a script
copied with `fs.copy`, a fixture under `testdata/`, a generated index
under `o/`) declares it with a `--- reads: <path>` line in its header,
one path per line; the runner re-records the result when that file
changes. Without the line an edit to the file reuses the last recorded
pass." Quote one existing declaration as the example
(`_build/doc_symbols_test.tl`'s). `_cli/gitboard_root_test.tl` (PR
1764, once merged) gains `--- reads: bin/gitboard`.
