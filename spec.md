## Evidence

`MODE=cov` writes a correct, merge-safe `.gcda` per instrumented
object today (cosmic-lua/cosmopolitan#359/#362/#380, items
3Il43qrU0v1rsyrdnssXqBUOjuH / 3Ilf3Lh50nV3sLMPXBo7Y4J6NcJ /
3Ip8xYTOwHNyZ9ZMWNCqqTpaJfw, all `completed`), and #362's own PR body
already recorded real numbers off it — a serial `make MODE=cov
o/cov/tool/lua/test` put `lsqlite3.c` at 38.20% of 1034 lines and
`llua.c` at 90.56% of 413 — but nothing turns that into a committed,
ratcheted floor: no floor file exists for line coverage (only
`tool/lua/coverage_floor.lua`, the unrelated FUNCTION-coverage floor
from `--ftrace`, ratcheted in DEFAULT mode, not `cov`), and no `.ok`
rule in `tool/lua/BUILD.mk`'s `ifeq ($(MODE),cov)` block (lines
506-538 today) reads a `.gcno`/`.gcda` pair at all. This is the literal
gap between what exists and the outcome's own ask: "A per-file C
line-coverage floor for the binding sources, ratcheted the way
`.cosmic-coverage` is."

The 13 instrumented binding sources and the exact object each one's
gcov data lives at, all under `o/$(MODE)/` (`tool/lua/BUILD.mk`'s
`TOOL_LUA_LUA_MODULES`, `third_party/lua/BUILD.mk:195`'s
`THIRD_PARTY_LUA_UNIX_OBJS`, and `tool/lua/coverage_floor.lua`'s own
13-file key set, which this floor should match exactly):

| source file                        | object (under `o/$(MODE)/`)      |
|-------------------------------------|-----------------------------------|
| `third_party/lua/cosmo/lunix.c`     | `third_party/lua/cosmo/lunix.o`   |
| `tool/lua/lcosmo.c`                 | `tool/lua/lcosmo.o`               |
| `tool/net/largon2.c`                | `tool/net/largon2.o`              |
| `tool/net/lcov.c`                   | `tool/net/lcov.o`                 |
| `tool/net/lfetch.c`                 | `tool/net/lfetch.o`               |
| `tool/net/lfuncs.c`                 | `tool/lua/lfuncs3.o`  **not** `tool/net/lfuncs.o` |
| `tool/net/lgetopt.c`                | `tool/net/lgetopt.o`              |
| `tool/net/ljson.c`                  | `tool/net/ljson.o`                |
| `tool/net/llua.c`                   | `tool/net/llua.o`                 |
| `tool/net/lpath.c`                  | `tool/net/lpath.o`                |
| `tool/net/lre.c`                    | `tool/net/lre.o`                  |
| `tool/net/lsqlite3.c`               | `tool/net/lsqlite3.o`             |
| `tool/net/lzip.c`                   | `tool/net/lzip.o`                 |

`tool/net/lfuncs.c` is the one file compiled into two different
objects (`tool/net/BUILD.mk:127-132` instruments `tool/net/lfuncs.o`
for other `MODE=cov` binaries; `tool/lua/lfuncs3.c` `#include`s the
same source and compiles as `tool/lua/lfuncs3.o`, which is the one
`TOOL_LUA_LUA_MODULES` actually LINKS into `o/$(MODE)/tool/lua/lua.dbg`
— the test binary this test target builds). `o/$(MODE)/tool/lua/test`
never builds or runs anything that links `tool/net/lfuncs.o`, so its
`.gcno`/`.gcda` (if either exists at all under this test target) holds
no coverage from these tests; `lfuncs3.o`'s does, the same way
`tool/lua/coverage.lua`'s function floor already derives `lfuncs.c`'s
covered set from `nm -l` on `lua.dbg` itself rather than from the
`tool/net/lfuncs.o` object.

`gcov`'s `--json-format`/`-j` flag (available on the host `gcov`
13.3.0 this repo's research already used, per item
3Il1RVDaKyr00zNMfdvnoW6jglZ's `## Result`) gives exact per-line hit
counts with no percentage-rounding, and its output-naming convention
was NOT previously measured in any item — reproduced here on a
throwaway file with the host gcc/gcov (this sandbox has no cosmocc
toolchain to build the real objects, so this confirms `gcov`'s own
behavior, not the real `.gcno` cosmocc emits; re-verify against a real
`o/cov/tool/net/lpath.o.gcno` when building this item):

    $ gcc -fprofile-arcs -ftest-coverage -dumpdir obj/tool/net/ \
        -dumpbase lpath.o -c -o obj/tool/net/lpath.o tool/net/lpath.c
    $ ./a.out   # exercises 6 of 9 lines
    $ gcov -j -o obj/tool/net obj/tool/net/lpath.o.gcno
    File 'tool/net/lpath.c'
    Lines executed:66.67% of 9
    Creating 'lpath.o.gcov.json.gz'      <- named after the OBJECT
                                             (lpath.o), not the source
                                             (lpath.c); written to CWD,
                                             not -o's directory
    $ gunzip -c lpath.o.gcov.json.gz | python3 -m json.tool | head -40
    {
      "format_version": "1", "gcc_version": "13.3.0", ...
      "files": [ { "file": "tool/net/lpath.c",
        "lines": [
          {"line_number": 1, "function_name": "add", "count": 1, ...},
          {"line_number": 2, "function_name": "add", "count": 1, ...},
          ... one entry per executable line, "count" the exact hits ...
        ] } ] }

Grouping by `line_number` (max `count` per line, in case a line holds
more than one block) and counting `count > 0` gives 6 covered of 9
total — exactly the 66.67%×9 gcov's own summary reported, cross-
checked. `cosmo.Inflate(data, {format = "gzip"})`
(`tool/net/definitions.lua:2972`, gzip framing documented at line
2448) and `cosmo.DecodeJson` (`tool/net/definitions.lua:2405`) are
already-bound primitives that read this without any new C code.

## Change

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

## Non-goals

- No change to which bindings the tests exercise (raising coverage,
  once the floor makes a regression visible, is ordinary follow-on
  work — inherited from the parent outcome's own non-goal).
- No instrumentation outside `tool/net`, `tool/lua`, and
  `third_party/lua/cosmo` (inherited from the parent outcome).
- No change to `.github/workflows/pr.yml` — 3IvOr6Gxxn8pZGF53TUjsyrD5ML
  (ranked before this item) already makes CI build and run
  `o/cov/tool/lua/test`; once that lands, this item's new `.ok` gate is
  enforced on every PR with no further workflow change.
- No change to `tool/lua/coverage.lua` / `coverage_floor.lua` — the
  function-coverage floor stays exactly as-is; this item adds a
  parallel, differently-named mechanism, not a replacement.
