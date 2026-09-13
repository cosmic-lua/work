Two files. `_fuzz/shrink.tl` is NOT touched: the budget hook is the
driver's (it owns `arm_budget`/`disarm_budget` and the one VM hook
slot), and shrink.tl cannot require driver.tl without a circular
require. The driver therefore hands shrink a check that is already
budget-capped, which needs no signature change anywhere and leaves
shrink's four test call sites alone.

### 1. `_fuzz/driver.tl` — pass shrink a budgeted check

Add one local, directly above `failure()`:

```teal
--- Wrap a property's check so each call runs under the budget hook.
--- Shrinking reruns check on every candidate, and it must not do so
--- unbudgeted: the candidate that loops is the very input the budget
--- exists to attribute. A throw becomes a false return, which is what
--- shrink's still_fails already makes of one, so a budget-exceeded
--- candidate reads as still failing and is kept.
--- @param check function The property's check
--- @param budget integer VM instructions one call may spend
--- @return function The same contract, budget-capped per call
local function budgeted(
    check: function(input: string): boolean, string, budget: integer
  ): function(input: string): boolean, string
  return function(input: string): boolean, string
    local armed = arm_budget(budget)
    local ok, held, why = pcall(check, input)
    if armed then
      disarm_budget()
    end
    if not ok then
      return false, tostring(held)
    end
    if not held then
      return false, tostring(why or "no detail")
    end
    return true
  end
end
```

Then change the one call site (driver.tl:170) from

```teal
local minimized_draws = shrink.shrink(opts.gen, opts.check, rec.draws)
```

to

```teal
local minimized_draws = shrink.shrink(
  opts.gen, budgeted(opts.check, budget), rec.draws)
```

`opts.gen` is deliberately NOT wrapped: `run_in_process` already calls
it outside the budget (driver.tl:153, before `arm_budget`), and this
item does not change where the budget's edge sits.

Correct the `disarm_budget()` call site's surroundings only insofar as
the doc comment on `Options.budget` claims the budget bounds "one
check() invocation" — it now bounds every check invocation including
shrink's candidates. Amend that clause; change no other prose.

### 2. `_fuzz/driver_test.tl` — make the two dead tests live, and add the candidate case

- `test_a_looping_property_fails_within_its_budget` (line 245): replace
  `gen = function(_src: source.Recorder): string return "input" end`
  with `gen = function(src: source.Recorder): string return
  driver.bytes(src, 8) end`. Every existing assertion in the test
  stands unchanged (`seed=`, `iteration=1`, `budget=100000 exceeded`) —
  measured with the fix applied, the message is
  `looper_that_draws: seed=1 iteration=1 input(base64)= draws=6:
  budget=100000 exceeded`.
- `test_the_budget_hook_is_cleared_between_runs` (line 287): the same
  substitution for its `arms_a_tiny_budget` property's gen. Its second
  half (`draw_heavy_afterwards`) is unchanged.
- Add `test_a_shrink_candidate_that_loops_is_caught`, called on the line
  after its `end`, inside `without_coverage`: `gen = driver.bytes(src,
  8)`, `budget = 100000`, and a check that loops on inputs shorter than
  4 bytes and returns `false, "too big"` otherwise. Assert the run
  returns false and that the message contains `too big` — the ORIGINAL
  failure's detail, not the candidate's — which is what pins that a
  looping candidate is caught without changing what gets reported.
