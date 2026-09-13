- No change to any `*_fuzz_test.tl` file — isolation is unconditional
  in `driver.tl` and needs no `Options.isolate` flag or per-file edit.
- No per-iteration subprocess spawning — isolation is per-PROPERTY
  (one child per `driver.run` call); only a confirmed crash triggers
  further (per-iteration) bisection respawns.
- No change to the existing VM instruction-budget hook
  (`arm_budget`/`disarm_budget`) — it remains the primary hang defense
  when the hook slot is free; `timeout_ms` is only the wall-clock
  backstop for when it is not (under the instrumented coverage stage).
- No minimization (`shrink.shrink`) of a crashing input — the crash
  case reports the raw input at the bisected iteration, unminimized.
  Shrinking a crash safely (running `shrink.shrink` itself inside
  isolation) is follow-up work, not this item's.
- No corpus persistence (`testdata/`, item 6) and no discard accounting
  (item 7) — separate children.
- No `cosmic.fuzz` publishing move (item 8, still blocked on the
  placement decision the epic's own spec has not yet settled).
- No change to `cosmic.child` or `cosmic/child/*.tl` — `Result` already
  carries every field this item needs (spiked above).
