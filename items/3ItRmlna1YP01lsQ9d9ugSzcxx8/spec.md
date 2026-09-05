## Evidence

cosmic's perf harness is internal — `_perf/harness.tl`, `_perf/perf_types.tl`,
`_perf/stats.tl`, `_perf/compare.tl`, `_perf/gate.tl`, `_perf/run.tl` all sit
under a leading-underscore tree, embedded in the cosmic binary "never in user
artifacts" (AGENTS.md, Repository Layout) — yet it already has a downstream
consumer. cosmic-lua/work's `.github/workflows/perf.yml` (lines 61-70,
2026-09-05) does `git clone --depth 1 https://github.com/cosmic-lua/cosmic
/tmp/cosmic-perf-src` on every run purely to reach those files, and
`_perf/bench/verbs_bench.tl`'s header (lines 17-30) documents resolving
`_perf.harness`/`_perf.perf_types` "against a checkout of cosmic-lua/cosmic".
A project that wants cosmic's noise-aware compare gate has to check out
cosmic's source tree; nothing in the binary serves it.

The same gap shows up twice more in that one consumer: `_work/flowstats.tl:209`
hand-rolls `percentile` over a sorted list while `_perf/stats.tl` already has
`sorted`/`min`/`max`/`mean`/`median`/`stddev`/`spread_pct`; and
`_perf/fixture.tl` in work re-derives "how long a scenario may take under the
harness's default calibration" (its line 51) from reading `harness.tl` rather
than from a documented contract.

`cosmic --docs` (2026-09-05) lists no `bench`, `perf`, or `stats` module.

## Change

1. A public `cosmic/bench/` directory (the `cosmic/fs/` shape): `init.tl`
   (`run_scenario`, `run_all`, `format_ns`, `format_line` — today's
   `_perf/harness.tl`), `types.tl` (`Scenario`, `Options`, `Measurement`,
   the JSON results shape — today's `_perf/perf_types.tl`), `stats.tl`
   (today's `_perf/stats.tl` plus `percentile(sorted, p)`), `compare.tl`
   and `gate.tl` (the noise-aware compare, `selfcheck`, the verdict line).
   `_perf/` keeps only cosmic's own scenarios (`_perf/bench/*_bench.tl`),
   `run.tl`/`gate.tl` become thin entry points over `cosmic.bench`, and
   `baseline.tl`/`baserun.tl`/`reproduce.tl` stay internal (they know
   cosmic's release layout).
2. The results JSON format and the compare thresholds are the public
   contract: document them in the module header, and keep `_perf/gate.tl
   compare` byte-compatible with results files written before the move
   (`_perf/gate_test.tl`'s fixtures are the proof).
3. The calibration budget (what `run_scenario` spends per scenario by
   default) becomes a documented `Options` field, so a downstream fixture
   need not read the harness to size itself.
4. Tests move with the code (`harness_test`, `stats_test`, `compare_test`,
   `gate_*_test`); a `cosmic/bench_example.tl` runs one trivial scenario.
5. Then, on the work side (its own follow-up, not this item): `perf.yml`
   drops the clone and runs `bin/cosmic _perf/run.tl` against
   `cosmic.bench`; `flowstats.percentile` goes.

## Non-goals

Changing what the harness measures or how the gate decides; making
`perf.yml`'s daily compare into a release gate (D44 stands); the work-side
port (a follow-up once this ships in a release).
