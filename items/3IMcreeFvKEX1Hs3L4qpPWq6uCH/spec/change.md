Add one new file, `cosmic/sqlite/zipfile_test.tl` (absent today:
`ls cosmic/sqlite/zipfile_test.tl` reports No such file). Follow
`cosmic/sqlite/data_test.tl` for shape: module-level
`local TEST_TMPDIR = os.getenv("TEST_TMPDIR")`, `cosmic.*` requires
only, `check.must` for fallible returns, each `test_*` function called
on the line after its `end`.

Write exactly these three test functions, in this order — one per
property the example leaves uncovered, and nothing else:

1. `test_zipfile_module_is_registered` — open `:memory:`, then
   `query_one("SELECT name FROM pragma_module_list WHERE name = 'zipfile'")`
   and assert the row's `name` is `"zipfile"`, with a failure message
   naming `sqlite3_zipfile_init` in `tool/net/lsqlite3.c` as what to
   look at. This is the sentinel: it fails loudly and specifically if
   an upstream merge drops the registration.

2. `test_every_documented_column_is_selectable` — `proc.interpreter()`
   for the artifact path, then one
   `SELECT name, mode, mtime, sz, rawdata, data, method FROM zipfile(?)
   WHERE name = 'cosmic/fs.lua'`, asserting each of the seven columns
   is non-nil. These are the columns `docs/guides/artifacts.md:17-19`
   documents. Selecting the member by name is what proves it is
   readable; do not add a separate count-the-members test, and do not
   assert any total.

3. `test_failure_modes_report_their_cause` — three assertions on the
   error strings measured above: a second `INSERT` of an existing
   member name returns false with an error containing `duplicate name`;
   `zipfile()` over a file written with `fs.write(..., "not a zip")`
   fails with an error containing `end of central directory`; and
   `zipfile()` over a path under `TEST_TMPDIR` that was never created
   fails with an error containing `cannot open file`. Match with
   `s:find(needle, 1, true)` — a literal substring, never a pattern.
   The duplicate-name path needs a writable archive, so `fs.copy` the
   interpreter to `fs.join(TEST_TMPDIR, "artifact")` and
   `CREATE VIRTUAL TABLE z USING zipfile('<copy>')` over the copy —
   never over the artifact the test is running from. This is the only
   test that copies the artifact.

Write no `as` casts anywhere in the file: reach values through
`tostring`/`tonumber` instead, so `_build/casts_baseline.tl` needs no
row. Keep the file at or under 120 lines.
