--- Wall-clock scenarios for `o/bin/gitboard`, one per verb, over a
--- generated fixture (`_perf.fixture`): each `fn` spawns the built binary
--- through `cosmic.child`, `GITBOARD_DIR` pointed at a fixture checkout,
--- so the binary's own process-startup and git-subprocess cost is inside
--- the number the same way `_perf/bench/startup_bench.tl` spawns cosmic
--- itself. gitboard's cost is git processes, not Lua (see this item's
--- Evidence on the board) — `strace -f -e trace=execve` is the tool for
--- diagnosing a slow reading, never a gate here: nothing in this module
--- fails a scenario for being slow, only for answering wrong.
---
--- Running: cosmic's `_perf/run.tl`, invoked BY PATH from a cosmic
--- checkout, resolves `_perf.bench.verbs_bench` and every `_perf.*`
--- import it makes against THIS tree, not a copy embedded in the pinned
--- binary — confirmed by running it from this tree's root:
---
---   PERF_BIN=$PWD/o/bin/gitboard \
---     bin/cosmic /path/to/cosmic/_perf/run.tl --out o/perf/current.json
---
--- `PERF_BIN` is cosmic's own `_perf/run.tl` variable (`collect_meta`):
--- without it, the results file's `bin`/`bin_sha` name whichever cosmic
--- is RUNNING the harness — the same pinned `bin/cosmic` on every run —
--- so two results files always read as the "same binary" to `gate.tl
--- compare`'s identity check, whatever `GITBOARD_PERF_BIN` (below)
--- pointed the SCENARIOS themselves at. The two must be set together
--- and named the same file, never sync'd, only set independently by
--- whoever invokes `run.tl` (`.github/workflows/perf.yml` sets both).
---
--- discovers `_perf/bench/*_bench.tl` relative to the working directory
--- (this repository), while resolving `_perf.harness`/`_perf.perf_types`
--- relative to the SCRIPT's own path (that cosmic checkout) — the two
--- roots differ and both resolve correctly, so cosmic's runner is the
--- whole of it: nothing here re-implements `_perf/run.tl` or `gate.tl`.
---
--- Read-only scenarios (`show`, `show_id`, `next`, `find`, `fsck`, `sync`)
--- share ONE fixture clone — nothing here writes to it, `sync` included
--- (a local bare origin has nothing new to fetch after the fixture push).
--- `cold_show` and the mutations each get their OWN fresh clone from
--- `setup`, so one scenario's writes are never another's residue, and a
--- mutation's repeated `fn` calls (the harness times a scenario's `fn`
--- several times against the SAME setup) land on the SAME clone as any
--- ordinary repeated invocation of the real verb would.
local env = require("cosmic.env")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local check = require("cosmic.check")
local fixture = require("_perf.fixture")
local pt = require("_perf.perf_types")

local GITBOARD_BIN < const > = os.getenv("GITBOARD_PERF_BIN") or "o/bin/gitboard"

--- What one spawn needs checked: its exit code and its verdict line.
local record Run
  code: integer
  stdout: string
end

--- Spawn `o/bin/gitboard` with `argv_tail`, `GITBOARD_DIR` set to `dir`.
--- @param dir string The state repository checkout to operate on
--- @param argv_tail {string} Arguments after the binary path
--- @return Run
local function spawn(dir: string, argv_tail: {string}): Run
  local argv: {string} = {GITBOARD_BIN}
  for _, a in ipairs(argv_tail) do
    argv[#argv + 1] = a
  end
  local envlist = env.list({set = {GITBOARD_DIR = dir}})
  local r, rerr = child.run(argv, {env = envlist})
  assert(r ~= nil, tostring(rerr))
  return {code = r.code, stdout = r.stdout}
end

--- A scenario's `check`: exit 0, and its verdict line carries the verb's
--- own `gitboard-<verb>:` prefix (`show ID` verdicts as plain `show`,
--- same as bare `show` — both go through `_work.gitgate.verdict_line`).
--- @param verb string
--- @return function(any, any): boolean, string
local function verdict_check(verb: string): function(any, any): boolean, string
  local prefix = "gitboard-" .. verb .. ":"
  return function(_: any, result: any): boolean, string
    local r = result as Run -- cast: every `fn` in this file returns a Run
    if r.code ~= 0 then
      return false, ("exit %d: %s"):format(r.code, r.stdout)
    end
    if not r.stdout:find(prefix, 1, true) then
      return false, ("missing %q in: %s"):format(prefix, r.stdout)
    end
    return true
  end
end

--- Every scenario below sets its `ctx` from its own `setup`, always a
--- directory string; `pt.Scenario`'s `any` is generic, nothing else ever
--- flows through it here.
--- @param ctx any
--- @return string
local function as_dir(ctx: any): string
  return ctx as string -- cast: every `setup` in this file returns a directory string
end

local built: fixture.Fixture | nil

local function scenarios(): {pt.Scenario}, string
  if not fs.is_file(GITBOARD_BIN) then
    return nil, "cannot locate " .. GITBOARD_BIN .. " (run `cosmic --make build`, "
    .. "or set GITBOARD_PERF_BIN)"
  end
  local fx, ferr = fixture.build()
  if fx == nil then
    return nil, "fixture: " .. ferr
  end
  built = fx

  local new_titles = 0
  local done_next = 0

  local out: {pt.Scenario} = {
    {
      name = "show",
      setup = function(): any, string return fx.clone, nil end,
      fn = function(ctx: any): any return spawn(as_dir(ctx), {"show"}) end,
      check = verdict_check("show"),
    },
    {
      name = "show_id",
      setup = function(): any, string return fx.clone, nil end,
      fn = function(ctx: any): any
        return spawn(as_dir(ctx), {"show", fx.sample_id})
      end,
      check = verdict_check("show"),
    },
    {
      name = "next",
      setup = function(): any, string return fx.clone, nil end,
      fn = function(ctx: any): any return spawn(as_dir(ctx), {"next"}) end,
      check = verdict_check("next"),
    },
    {
      name = "find",
      setup = function(): any, string return fx.clone, nil end,
      fn = function(ctx: any): any return spawn(as_dir(ctx), {"find", "fixture"}) end,
      check = verdict_check("find"),
    },
    {
      name = "fsck",
      setup = function(): any, string return fx.clone, nil end,
      fn = function(ctx: any): any return spawn(as_dir(ctx), {"fsck"}) end,
      check = verdict_check("fsck"),
    },
    {
      name = "sync",
      setup = function(): any, string return fx.clone, nil end,
      fn = function(ctx: any): any return spawn(as_dir(ctx), {"sync"}) end,
      check = verdict_check("sync"),
    },
    {
      -- The cache removed before EVERY timed call, not only before the
      -- first: `fn` is the same function the harness calls for warm-up,
      -- calibration, every sample, and the allocation probe, so only
      -- deleting `o/board.db` once in `setup` would time a cold rebuild
      -- exactly once and a warm re-read for everything after it —
      -- reporting `show`'s own number under a different name.
      name = "cold_show",
      setup = function(): any, string
        return check.must(fixture.fresh_clone(fx.bare, fx.root .. "/cold")), nil
      end,
      fn = function(ctx: any): any
        local dir = as_dir(ctx)
        local _ok, _err = fs.remove(fs.join(dir, "o", "board.db"))
        return spawn(dir, {"show"})
      end,
      check = verdict_check("show"),
      teardown = function(ctx: any)
        local _ok, _err = fs.remove_all(as_dir(ctx))
      end,
    },
    {
      name = "new",
      setup = function(): any, string
        return check.must(fixture.fresh_clone(fx.bare, fx.root .. "/new")), nil
      end,
      fn = function(ctx: any): any
        new_titles = new_titles + 1
        return spawn(as_dir(ctx), {"new", "perf new item " .. new_titles,
            "--parent", fx.sample_id})
      end,
      check = verdict_check("new"),
      teardown = function(ctx: any)
        local _ok, _err = fs.remove_all(as_dir(ctx))
      end,
    },
    {
      -- `compare_winner`/`compare_loser` already carry this edge (the
      -- fixture places every root against its neighbor), so every call
      -- here — the first included — is the no-op path: exactly the
      -- steady-state cost of a session re-asserting a standing judgment,
      -- which is the common case (`compare` is idempotent by design).
      name = "compare",
      setup = function(): any, string
        return check.must(fixture.fresh_clone(fx.bare, fx.root .. "/compare")), nil
      end,
      fn = function(ctx: any): any
        return spawn(as_dir(ctx), {"compare", fx.compare_winner, fx.compare_loser})
      end,
      check = verdict_check("compare"),
      teardown = function(ctx: any)
        local _ok, _err = fs.remove_all(as_dir(ctx))
      end,
    },
    {
      -- Each call resolves a DIFFERENT item from `fx.done_pool`: `done`
      -- cannot be re-run on the same item, unlike every other mutation
      -- here, so the fixture reserves a pool sized above what one
      -- scenario run ever spends (see `_perf.fixture`'s `DONE_POOL_SIZE`).
      name = "done",
      setup = function(): any, string
        return check.must(fixture.fresh_clone(fx.bare, fx.root .. "/done")), nil
      end,
      fn = function(ctx: any): any
        done_next = done_next + 1
        local id = fx.done_pool[done_next]
        assert(id ~= nil, "done_pool exhausted: raise _perf.fixture.DONE_POOL_SIZE")
        return spawn(as_dir(ctx), {"done", id, "--reason", "not-planned"})
      end,
      check = verdict_check("done"),
      teardown = function(ctx: any)
        local _ok, _err = fs.remove_all(as_dir(ctx))
      end,
    },
  }
  return out
end

local function cleanup()
  if built ~= nil then
    local _ok, _err = fs.remove_all(built.root)
    built = nil
  end
end

local M: pt.BenchModule = {
  scenarios = scenarios,
  cleanup = cleanup,
}

return M
