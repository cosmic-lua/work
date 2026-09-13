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
