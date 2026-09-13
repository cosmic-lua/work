- **No change to `.github/workflows/fuzz.yml`.** A per-lane timeout
  would fix this repo's cron and leave every other consumer of the
  driver with the same constant; the driver owns the rule.
- **`Options.timeout_ms` stays an absolute override.** Not a floor, not
  a per-iteration rate. `driver_test.tl:362` depends on 200 meaning
  200ms, and a caller who names a wall clock means it.
- **No change to the bisection probes' budget.** `bisect_crash`
  respawns with FEWER iterations under the same timeout, so a probe can
  only finish sooner than the run that produced it; scaling each probe
  down separately buys nothing and adds a second rule.
- **No change to `DEFAULT_BUDGET` or the VM instruction hook.** This
  item is the wall clock only. The two backstops are independent and
  the budget is not implicated in the observed red.
- **Not the empty-input report.** A genuine timeout still reports
  `input(base64)= draws=0`, because `isolate()` has no failing input to
  name when the child never came back — the scaling removes the FALSE
  timeouts, and whether a real one should report differently is its own
  item, not this diff.
- **No change to `failure()`, the `"hung: exceeded %dms"` text, or any
  other message shape.** `driver_test.tl`'s substring assertions and
  the workflow's log expectations both read them.
