At each site below, replace the `as` cast with an `is` guard against the
type the site already names, and give the negative branch the failure the
surrounding code already has a shape for (a `nil, msg` return in library
code, an `assert` in a test). Over `any`, `x is Rec` compiles to one
`type(x) == "table"` test and `x is string` to one `type(x) == "string"`
test — the same mechanism PR #1382 used for `_cli/main_handlers.tl` and
`cosmic/init.tl`, and the one AGENTS.md names ("Use `is` for dispatch past
nil … also dispatch over `any`"). No cast replaces any of the twelve.

Sites, re-measured 2026-08-26 against `c2ae0466` with
`git ls-files '*.tl' | xargs grep -n -- "-- cast: .*from any"`. Every
record named below is already declared at the site, at the line range
cited; nothing new is declared except where stated. All twelve sites and
their per-file counts are unchanged since the first measurement; two line
numbers moved and are corrected below.

**Library (4 casts, 3 files).**
- `cosmic/quicksand/box/init.tl:43` — `require("cosmic.quicksand") as
  CapsModule` inside `caps()`. `CapsModule` is declared at `:38–40`. Guard
  it; when the require does not yield the record, return the empty
  `types.Capabilities` the caller already handles rather than indexing a
  non-table. (205 lines, 295 of headroom.)
- `cosmic/quicksand/box/init.tl:150` — `require("cosmic.quicksand.box.run")
  as RunModule` inside `run()`. `RunModule` is declared at `:137–139`. The
  function returns `integer | nil, string`, so the negative branch is a
  `nil, "quicksand: box run module unavailable"`.
- `cosmic/quicksand/box/run.tl:68` — the same lazy `require("cosmic.quicksand")`,
  taken to break the umbrella's re-export cycle (the comment at `:66–67`
  says so and stays). Guard it; the branch it feeds only decides whether
  `CLONE_NEWPID` joins `flags`, so a failed guard leaves `flags` unchanged.
  (342 lines, 158 of headroom.)
- `cosmic/doc/query.tl:39` — `result as DocIndex`, where `result` is the
  value of a `pcall(chunk)` over the embedded index. The function already
  returns `nil, string` on both preceding failures, so the guard's negative
  branch is `return nil, "index is not a doc index"`. **`cosmic/doc/query.tl`
  is 479 lines — 21 of headroom under the 500-line cap** (`wc -l
  cosmic/doc/query.tl`); the change is line-neutral to +3 and must stay
  under it, which is why `Acceptance` measures it.

**Tests (8 casts, 6 files).** Each of these is a test asserting on a value
it created or a module it required; the guard replaces the cast and the
`assert` message names what did not arrive.
- `_docs/publish_test.tl:58` — `require("_docs.publish") as PublishModule`;
  `PublishModule` is declared at `:8–11`.
- `cosmic/searcher_test.tl:41` — `require(name) as {string: integer}`,
  where `name` is a fixture module minted by the test. `is {string:
  integer}` is the map-type form AGENTS.md names.
- `_perf/perf_test.tl:49` — `mod as pt.BenchModule` from a
  `pcall(require, name)` over discovered bench modules. The two `assert`s
  on the next lines already check `scenarios`/`cleanup`; the guard goes
  in front of them.
- `_perf/run.tl:165` — `mod as pt.BenchModule` in `load_module`, which
  returns `pt.BenchModule, string`: the negative branch is the `nil, name
  .. ": not a bench module (missing scenarios())"` the next `if` already
  produces.
- `cosmic/fs/path_test.tl:196` — `c as WalkContext` inside the
  `fs.visit` visitor. `fs.visit`'s context parameter is `any` by contract
  and does not move (see Non-goals).
- `_perf/harness_test.tl:16`, `:40`, `:43` — `res as string`, `(ctx as
  {string: string}).token`, `res as string`. The harness types scenario
  contexts and results `any` by contract; these are the test's own values,
  so `is string` / `is {string: string}` narrow them.

**The ratchet.** `_build/casts_baseline.tl` is a committed floor whose rows
count every cast in a file, not only the `from any` ones. When the gate
complains, run exactly the command its failure message prints —
`bin/cosmic --make run _build/casts.tl --baseline` — and commit the result;
no gate is weakened any other way. The expected row moves (today's totals
from `grep -c -- "-- cast:" <file>`, and `[path] = n` rows read from the
floor):

| file | row today | row after |
| --- | --- | --- |
| `cosmic/quicksand/box/init.tl` | `= 3` | `= 1` |
| `cosmic/quicksand/box/run.tl` | `= 2` | `= 1` |
| `cosmic/doc/query.tl` | `= 1` | row absent |
| `_docs/publish_test.tl` | `= 1` | row absent |
| `cosmic/searcher_test.tl` | `= 2` | `= 1` |
| `_perf/perf_test.tl` | `= 2` | `= 1` |
| `_perf/run.tl` | `= 2` | `= 1` |
| `cosmic/fs/path_test.tl` | `= 1` | row absent |
| `_perf/harness_test.tl` | `= 3` | row absent |

A row at zero is absent from the floor by construction — `_build/casts.tl`
emits only files with at least one cast — so four rows disappear rather
than reading `= 0`.
