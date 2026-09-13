Two files: `_fuzz/source.tl` and `_fuzz/driver.tl`, plus the tests in
`_fuzz/driver_test.tl`. `_fuzz/shrink.tl` is NOT touched.

### 1. `_fuzz/source.tl` — a replay Recorder records what it CONSUMES

In `replay` (source.tl:55-85), stop aliasing the input list into the
Recorder and accumulate the consumed draws instead. Replace

```teal
  local rec: Recorder = {draws = draws}
```

with

```teal
  local consumed: {Draw} = {}
  local rec: Recorder = {draws = consumed}
```

and append `d` in each accessor, after its `nil` guard and before the
`return v`:

```teal
    consumed[#consumed + 1] = d
```

— once in `rec.int` and once in `rec.float`. Amend `replay`'s doc
comment to say that the returned Recorder's `draws` holds what has been
consumed so far, not the sequence it was given.

This is the placement to use, not a private helper in `driver.tl`:
building the same consuming wrapper in the driver was measured at +34
lines there (`driver.tl` 485 of 500), against +3 in `source.tl`, which
has 399 lines of headroom. `source.tl` already owns the record/replay
contract, so the count belongs with it.

### 2. `_fuzz/driver.tl` — one classifier, used at every check site

Add one local, replacing the inline classification currently inside
`run_in_process`'s loop, placed directly above `budgeted`:

```teal
--- Run check once on one input, under the budget hook, classifying
--- the outcome into the detail a failure reports.
--- @param check function The property's check
--- @param input string The input to check
--- @param budget integer VM instructions this call may spend
--- @return boolean True when the property held
--- @return string What failed, when it did not
local function attempt(
    check: function(input: string): boolean, string,
    input: string,
    budget: integer
  ): boolean, string
  local armed = arm_budget(budget)
  local ok, held, why = pcall(check, input)
  if armed then
    disarm_budget()
  end
  if not ok then
    local thrown = tostring(held)
    if thrown == BUDGET_MESSAGE then
      return false, ("budget=%d exceeded"):format(budget)
    end
    return false, "threw: " .. thrown
  end
  if not held then
    return false, tostring(why or "no detail")
  end
  return true, ""
end
```

Re-express `budgeted` on top of it, so one function decides what a
failed check is called, at all three sites (the loop, shrink's
candidates, the re-check below):

```teal
local function budgeted(
    check: function(input: string): boolean, string, budget: integer
  ): function(input: string): boolean, string
  return function(input: string): boolean, string
    return attempt(check, input, budget)
  end
end
```

`budgeted`'s doc comment stays as it is — the contract it describes is
unchanged.

Then rewrite the loop body's failure arm. From (driver.tl:195-215 on this
branch's base):

```teal
    local input = opts.gen(rec)
    local armed = arm_budget(budget)
    local ok, held, detail = pcall(opts.check, input)
    ...
    if not ok or not held then
      local what: string
      ...
      local minimized_draws = shrink.shrink(
        opts.gen, budgeted(opts.check, budget), rec.draws)
      local minimized_input = opts.gen(source.replay(minimized_draws))
      return false, failure(opts.name, seed, i, minimized_input, #minimized_draws, what)
    end
```

to:

```teal
    local input = opts.gen(rec)
    local held, what = attempt(opts.check, input, budget)
    if not held then
      local minimized_draws = shrink.shrink(
        opts.gen, budgeted(opts.check, budget), rec.draws)
      local replayed = source.replay(minimized_draws)
      local minimized_input = opts.gen(replayed)
      local still_held, minimized_what = attempt(opts.check, minimized_input, budget)
      if not still_held then
        what = minimized_what
      end
      return false, failure(
        opts.name, seed, i, minimized_input, #replayed.draws, what)
    end
```

Two decisions, both settled here:

- **The re-check runs under the budget** (it goes through `attempt`, not
  a bare `pcall`): a minimized input can be the one that loops, and a
  driver that hangs while composing its own failure message is the bug
  3ICDH3lW just removed from shrinking.
- **A minimized input that HOLDS keeps the original detail** (`if not
  still_held then`). Shrink only returns candidates `still_fails`
  accepted, so this is not expected; the branch exists so a
  non-deterministic property degrades to today's behaviour instead of
  reporting a failure with no detail.

Amend `run_in_process`'s doc comment (`driver.tl:174-189`) in one
clause to say the reported detail and draw count describe the MINIMIZED
input, not the original iteration. Change no other prose, and do not
touch the crash path's `#rec.draws` at driver.tl:329 — that recorder
comes from `source.new` and its count is already exact.

### 3. `_fuzz/driver_test.tl` — one new test, one flipped assertion

- Add `test_the_reported_detail_and_draws_describe_the_minimized_input`,
  called on the line after its `end`. Use the probe property from
  Evidence verbatim (`iters = 1`, `gen = driver.bytes(src, 256)`, a
  check that throws over 5 bytes and returns `false, "too long"` over
  2). Assert three things about the message: it contains `too long`, it
  does NOT contain `threw:`, and it contains `draws=4`. All three are
  measured — the fix produces `detail_probe: seed=1 iteration=1
  input(base64)=AAAA draws=4: too long`. It needs no `without_coverage`
  wrapper: the property sets no `budget` and never loops, so nothing
  depends on the VM hook.
- **Flip one assertion in
  `test_a_shrink_candidate_that_loops_is_caught`** (added by 3ICDH3lW).
  It currently asserts the message contains `too big` — the ORIGINAL
  iteration's detail — which is exactly the pairing this item removes.
  Measured with the fix applied, that test's message becomes
  `candidate_loops: seed=1 iteration=1 input(base64)= draws=1:
  budget=100000 exceeded`: shrinking minimizes to the empty input, which
  loops, so the budget catches it and the detail now describes the input
  actually reported. Change the assertion to `msg:find("budget=100000
  exceeded", 1, true)` and its message to say the reported detail matches
  the reported input. Leave the rest of that test alone — its
  `without_coverage` wrapper, its `ok == false` assertion, and above all
  its `FUZZ_SEED` pin: seed 1 is what makes the first input 5 bytes, so
  removing the pin puts the reported detail back at the mercy of the
  lane's rotating seed.
