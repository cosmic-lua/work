Bump the pin, then teach `arm_budget`/`disarm_budget` to prefer the
collector's budget.

- `3p/cosmos/cosmos_pin.tl`: bump `version` and the `sha` to the first
  release carrying `cosmo.cov.budget`. Follow AGENTS.md's pin-bump
  procedure: `bin/cosmic --make fetch`, then `bin/cosmic --make build`
  (which regenerates `o/_types/types_gen` from the new
  `definitions.lua`, so `cosmo.cov.budget` becomes a typed call with no
  regen step), then `o/bin/cosmic --make ci`.
- `_fuzz/driver.tl`, `arm_budget`: try the collector first. Resolve
  `cosmo.cov` the way `cosmic/coverage/init.tl:39` does — through
  `package.preload` so a runtime without the binding never executes a
  require — and call `cov.budget(budget)`. When it returns true, the
  budget is armed on the collector's hook: return true, and record
  which mechanism armed it so `disarm_budget` clears the right one.
  When it returns false (no collection running on this thread), fall
  through to today's `debug.gethook() ~= nil` test and
  `debug.sethook` path unchanged.
- `_fuzz/driver.tl`, `disarm_budget`: clear whichever was armed —
  `cov.budget(0)` for the collector's, the existing empty-mask
  `debug.sethook` for the Lua one. Keep it a plain pair of functions;
  a single `local armed_via: string = nil` upvalue beside them is
  enough state, and it stays correct because `run_in_process` arms and
  disarms around one `pcall` at a time.
- `_fuzz/driver.tl`, `BUDGET_MESSAGE`: the collector raises its own
  string, `"cosmo.cov: instruction budget exceeded"`. Recognize BOTH
  that and the existing `"_fuzz.driver: instruction budget exceeded"`
  at the comparison in `run_in_process` (`:163-166`), so a budget
  failure reports `budget=<n> exceeded` whichever hook caught it. Do
  not change the reported message format — `driver_test.tl:261` asserts
  `budget=100000 exceeded` verbatim.
- `_fuzz/driver.tl`, `Options.budget`'s doc comment (`:83-89`): replace
  the stand-down sentences with what is now true — the budget arms on
  the collector's own hook when collection is running, and on the VM
  hook otherwise; a hang inside a single C call is still out of reach
  of both.
- `_fuzz/driver_test.tl`: add
  `test_the_budget_holds_under_the_collector` — the looping property of
  `:245`, run WITHOUT the `without_coverage` bracket and with
  `coverage.start()` held, asserting the run fails with
  `budget=<n> exceeded`. Leave the two existing budget tests and the
  `without_coverage` helper in place: they cover the no-collector path,
  which is still the plain suite's path.
