One module and one test file. The rule lives in the driver, not in the
workflow, so every project using this driver gets it and not just this
repo's lane.

### 1. `_fuzz/driver.tl` — scale the wall clock with the iteration count

- Add a constant beside `DEFAULT_TIMEOUT_MS`:

  ```teal
  --- Wall-clock allowance per iteration, in milliseconds. The costliest
  --- property in this tree (tar_mutation_totality) measured ~1.05
  --- ms/iteration on a developer machine in 2026-08; ten times that
  --- leaves room for a CI container several times slower before a
  --- healthy deep-lane run is reported as a hang.
  local TIMEOUT_PER_ITER_MS = 10
  ```

- Add one local, directly above `isolate()`:

  ```teal
  local function timeout_for(opts: Options, iters: integer): integer
    if opts.timeout_ms then
      return opts.timeout_ms
    end
    return math.max(DEFAULT_TIMEOUT_MS, iters * TIMEOUT_PER_ITER_MS)
  end
  ```

  `DEFAULT_TIMEOUT_MS` is now the FLOOR rather than the value: at the
  256-iteration default it still binds (256 × 10 = 2560 < 30000), so
  nothing about shallow runs changes, and it only gives way past 3000
  iterations.

- In `isolate()`, replace `local timeout_ms = opts.timeout_ms or
  DEFAULT_TIMEOUT_MS` with `local timeout_ms = timeout_for(opts,
  iters)`. That one line is the whole behavioral change: the value
  already flows from there into `spawn_isolated` and `bisect_crash`.

- Export `timeout_for` on `DriverModule`, beside `run` and
  `run_unisolated`, so the rule can be asserted directly instead of by
  waiting out a real timeout. `_fuzz` is internal tooling, so this
  widens no published surface.

- Correct the two doc comments the current constant makes false:
  `DEFAULT_TIMEOUT_MS`'s own comment ("Only reached when the VM
  instruction hook cannot arm … or the hang is inside a single C call")
  is wrong at deep-lane depth and should say it is the floor of a
  budget that scales with the iteration count; the module comment's
  sentence about `Options.timeout_ms` should say the same in one
  clause.

### 2. `_fuzz/driver_test.tl` — one new test

Add `test_the_child_timeout_scales_with_the_iteration_count`, called on
the line after its `end` like every other test in the file, asserting
`driver.timeout_for` at four points and nothing else (it is a pure
function; no property runs, no child spawns, no clock is read):

- at the 256-iteration default, 30000 — the floor still binds;
- at 3000 iterations, 30000 — the floor binds right up to where the
  scaled value overtakes it;
- at 50000 iterations, 500000 — the deep lane's budget, ~10x the ~52s
  the costliest property actually needs;
- with `timeout_ms = 200` set on the options and 50000 iterations, 200
  — an explicit value is absolute, never scaled and never a floor.
