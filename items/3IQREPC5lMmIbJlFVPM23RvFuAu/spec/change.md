Five files; apply exactly these validated shapes.

**1. `cosmic/coverage/init.tl`** (`install_wrappers`): hoist both raw
lookups, guard once, and bind typed locals the closures capture:

```teal
  local co = coroutine as {string: any} -- cast: patch stdlib table
  local os_mod = os as {string: any} -- cast: patch stdlib table
  local raw_create = co["create"]
  local raw_exit = os_mod["exit"]
  -- The signature guards type raw_create's return as a real thread, so
  -- every downstream arm/resume site is plainly typed. A stdlib whose
  -- create or exit is not a function cannot occur; the guard leaves it
  -- unpatched rather than crashing mid-install.
  if not (raw_create is function(any): thread)
    or not (raw_exit is function(any, any)) then
    return
  end
  -- Narrowing does not cross into a closure; these typed locals carry it.
  local create_fn: function(any): thread = raw_create
  local exit_fn: function(any, any) = raw_exit
```

`arm` becomes `arm(cothread: thread)` with bare `ccov.arm(cothread)` /
`debug.sethook(cothread, on_line, "l")`; both wrapper closures call
`create_fn(f)` into a `cothread` local; the resume line keeps ONE
re-reasoned cast:

```teal
      -- Packing resume's mixed returns erases the element type to any.
      -- cast: table.pack's n field is an integer by contract
      return table.unpack(results, 2, results.n as integer)
```

and `os_mod["exit"]`'s wrapper calls `exit_fn(code, close)`. File ends
at 6 casts (2 patch-stdlib, 1 pack-n, 3 elsewhere in the file), 0
`from any`.

**2. `_tool/benchmark.tl`**: the existing
`type(bench_fn) ~= "function"` guard at `:156` becomes
`if not (bench_fn is function()) then` (same runtime test, credited by
the checker); add `local run_fn: function() = bench_fn` after it and
call `pcall(run_fn)` at `:183`, deleting the cast and its marker line.

**3. `_perf/run.tl:131–132`**:

```teal
  local argv_last = rawget(arg, -1)
  meta.bin = os.getenv("PERF_BIN") or (argv_last is string and argv_last) or "unknown"
```

**4. `cosmic/rand.tl`**: `choice` becomes
`local function choice<T>(list: {T}): T | nil` with `@param list {T}` /
`@return T | nil` (prose unchanged: nil only when the list is empty);
`RandModule.choice` becomes `function<T>(list: {T}): T | nil`.

**5. `cosmic/rand_test.tl:145`**: drop the cast —
`seen[assert(rand.choice({"x", "y", "z"}))] = true`.

**Validation trap, restated**: a bare `o/bin/cosmic --check types
cosmic/rand_test.tl` after editing `cosmic/rand.tl` reports the OLD
`any` return (the checker resolves `cosmic.*` from the running
binary's embedded source); gate with `bin/cosmic --make ci`, which
converges — refinement confirmed the full gate passes.

**The ratchet**: run exactly the printed regen —
`bin/cosmic --make run _build/casts.tl --baseline` — and commit.
Expected rows: `cosmic/coverage/init.tl` `= 11` → `= 6`;
`_tool/benchmark.tl` and `_perf/run.tl` rows absent (today `= 1`
each); `cosmic/rand_test.tl` `= 3` → `= 2`.
