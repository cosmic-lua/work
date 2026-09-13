`tool/lua/line_coverage.lua` (new): for each of the 13 (source,
object) pairs above, run the host `gcov --json-format -o
<dir of the object> <object>.gcno` from a scratch working directory
(e.g. `o/$(MODE)/tool/lua/covout/`, created if missing) so the
`<object base>.gcov.json.gz` files it writes land somewhere
predictable; read each back, `cosmo.Inflate` (gzip) then
`cosmo.DecodeJson`, and reduce `files[0].lines[]` to `{covered, total}`
by `line_number` as measured above. Compare the resulting table
against `tool/lua/line_coverage_floor.lua`:

- a file whose `covered` count is below its floor entry fails the run,
  naming the file and both numbers;
- a floored file whose object produced no `.gcno` (missing or empty)
  fails by name — this is a build regression, not silently skipped;
- an instrumented file with no floor entry fails by name, the same
  asymmetry `tool/lua/coverage.lua`'s function floor already enforces;
- a run that meets or exceeds every floor passes;
- `LINE_COVERAGE_BASELINE=1` rewrites `tool/lua/line_coverage_floor.lua`
  to exactly what the run measured (a distinct env var from function
  coverage's `COVERAGE_BASELINE=1` — the two floors are measured in
  different `MODE`s and must never rewrite each other by accident).

`tool/lua/line_coverage_floor.lua` (new): same shape as
`tool/lua/coverage_floor.lua` — one `{covered = N, total = N}` entry
per file above, with a header comment naming this file, the collector,
and the `LINE_COVERAGE_BASELINE=1` rewrite convention. Its 13 initial
values cannot be measured in this sandbox (no cosmocc toolchain
available here — see Evidence); establish them by first landing
`line_coverage.lua` with the floor file absent (or every entry at 0),
running `make MODE=cov o/cov/tool/lua/test LINE_COVERAGE_BASELINE=1`
once, and committing the table it prints, exactly as
3Il1RfbQnDkO4vgNmWp2BAVip7R (#354) established `coverage_floor.lua`'s
own initial numbers.

`tool/lua/BUILD.mk`, inside the existing `ifeq ($(MODE),cov)` block:
right after the line adding `test_gcda_merge.ok` to `TOOL_LUA_TESTS`,
snapshot the list so far (`TOOL_LUA_COV_BINDING_TESTS :=
$(TOOL_LUA_TESTS)`) and add:

```
o/$(MODE)/tool/lua/test_line_coverage.ok:				\
		o/$(MODE)/tool/lua/lua.dbg				\
		tool/lua/line_coverage.lua				\
		tool/lua/line_coverage_floor.lua			\
		$(TOOL_LUA_COV_BINDING_TESTS)
	$< tool/lua/line_coverage.lua
	@touch $@
TOOL_LUA_TESTS += o/$(MODE)/tool/lua/test_line_coverage.ok
```

so the gate always runs after every other `cov`-enrolled test has
exercised the bindings and merged its `.gcda` (never on a partial
run), and reruns whenever the script or the floor changes.
