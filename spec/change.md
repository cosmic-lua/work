1. `_make/project.tl` (451-line record at the end): export `read_ignore`
   and `is_ignored` through `ProjectModule`, doc comments included.
2. `_tool/coverage/report.tl`: the walk loads the scanned root's
   `.cosmicignore` patterns once; `is_excluded` takes them and drops
   the hardcoded `items/` branch; a path any pattern matches is
   excluded exactly as the build model would exclude it.
3. Tests: `_tool/coverage/report_test.tl` (or the suite's existing
   home for report tests) — a fixture tree with `.cosmicignore` naming
   a subdir: its files are excluded from the report; without the file,
   included; `testdata/` excluded regardless.
