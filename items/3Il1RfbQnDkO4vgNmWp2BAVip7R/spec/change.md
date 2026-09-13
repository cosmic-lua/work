1. A collector script `tool/lua/coverage.lua` run by `lua.dbg` itself:
   for every `tool/lua/test_*.lua`, run
   `o/$(MODE)/tool/lua/lua.dbg --ftrace <test> 2> o/$(MODE)/tool/lua/<test>.ftrace`
   (keep exit status; the existing `.ok` rules stay the correctness
   gate), union the last field of every `FUN` line across logs,
   strip `\.(isra|constprop|part|cold)\.[0-9]+$` suffixes.
2. Denominator: `x86_64-linux-cosmo-nm -l --defined-only
   o/$(MODE)/tool/lua/lua.dbg`, keep `T`/`t` symbols whose file,
   normalized (strip `<root>/` and `./`), is one of the binding
   sources; per file, `defined` = that set, `covered` = defined ∩
   union-of-logs.
3. Floor file `tool/lua/coverage_floor.lua` — literal table
   `{ ["tool/net/lsqlite3.c"] = {defined=N, covered=M}, ... }`, one
   entry per binding file with at least one defined function (13 on
   origin/master), committed; first values are what step 2 measures
   at landing.
4. Gate: a new rule `o/$(MODE)/tool/lua/test_coverage.ok` in
   `tool/lua/BUILD.mk` (same `@touch $@` shape as the existing `.ok`
   rules, PR #351) that runs the collector and fails when any file's
   `covered` drops below the floor or a floor entry's file is missing;
   `o/$(MODE)/tool/lua/test` depends on it. A `COVERAGE_BASELINE=1`
   env rewrites the floor.
5. Measure wall-clock of the ftrace pass under `MODE=` and `MODE=dbg`
   and record both in the PR; pick `dbg` unless it exceeds 3x the
   plain test time, in which case default mode with the inlining
   caveat documented in the collector's header comment.
