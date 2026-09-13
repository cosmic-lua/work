1. **`_fuzz/driver.tl`** (161 lines at `968fabb`): `Options.budget:
   integer` — VM instructions per `check()` invocation, default
   50_000_000 (the 23k measurement above, recorded in the doc comment).
   Around each `pcall(opts.check, input)`: when `debug.gethook()`
   returns nil, install
   `debug.sethook(function() error(BUDGET_MESSAGE, 0) end, "", budget)`
   and clear it in every exit path (tl's `sethook` declaration has no
   argless form; `debug.sethook(function() end, "")` is the same off
   state — Lua turns the hook off when mask and count are both zero).
   When the slot is occupied, skip arming — the occupant is the
   coverage collector, and the stand-down is documented on
   `Options.budget`. A budget failure reports like any property failure
   — seed, iteration, input, draws, plus `budget=<n> exceeded` (match
   the caught value against BUDGET_MESSAGE, raised at level 0 so the
   comparison is exact).
2. **`_fuzz/sse_fuzz_test.tl`**: delete the hand-rolled
   `Drained.is_bounded`/`steps`/`max_steps` machinery; `drain` loops to
   the terminal nil. The properties keep their semantic assertions
   (terminal_error, event comparison). Accepted, stated risk: under the
   instrumented coverage stage the budget stands down, so a
   yield-forever loop there hangs to the CI job timeout — the same
   exposure every other fuzz file already has today; the fuzz lane on
   the same commit fails fast with attribution.
3. **Tests** (`_fuzz/driver_test.tl`): (a) a property that loops
   forever fails within a small explicit budget, message naming seed,
   iteration and `budget=<n> exceeded`; (b) a property that finishes
   normally passes under an explicit budget; (c) the hook is cleared
   between runs — after the budget-failing run, a draw-heavy run whose
   total instruction count is far past the previous small budget still
   completes. Tests (a) and (c) need the slot: bracket them with
   `local was = coverage.is_running(); if was then coverage.stop() end`
   / `if was then coverage.start() end` (`cosmic.coverage`'s public
   nestable pair — stop keeps counts, a bare start() re-arms the hook,
   both verified at cosmic/coverage/init.tl:274,153,133), so they run
   meaningfully under both the plain and the instrumented suite.
