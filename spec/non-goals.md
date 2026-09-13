- **The table never gates.** goals.md, G6: "cosmic ahead on every defining path is
  the ambition the table reports, never a gate", and its outcomes preamble: "where
  peers are the scoreboard, a published table records absolute standing ... it never
  gates." No threshold, no comparison, no verdict about speed anywhere in this
  slice. The only thing that fails the `peers` job is a broken cosmic row — an
  unspawnable binary or a failed `check()` — which is wrongness, not slowness.
- **No cycles-per-task peers.** G1's eval instrument owns those (goals.md G1: "run
  against Python/Node/Go sandboxes on the same tasks"). Nothing in this slice counts
  agent cycles, tokens, or errors.
- **Checker-latency peers are deferred.** No `tsc` row, no `mypy` row, no peer for
  `teal_check_module`. It earns its own card once this table exists; picking a
  defensible checker analogue is an open question and is not settled here.
- **One metric only.** No `startup_run_teal` row, no compile row, no embed-cycle
  row, no RSS or memory column, no second table.
- **Do not touch the perf results schema or the suite.** `_perf/perf_types.tl`,
  `_perf/run.tl`, `_perf/compare.tl`, `_perf/gate.tl`, `_perf/baseline.tl` and every
  `_perf/bench/**` module stay byte-unchanged: `perf.json` is what #1122 will gate
  on, and a peer row inside it would gate peers by accident. Read `pt.Scenario`,
  `pt.Options` and `pt.Measurement`; add no field to them.
- **Nothing under `_perf/bench/`, and no `*_bench.tl` name.** A bench module is
  auto-discovered by `_perf/run.tl` and by `_perf/perf_test.tl`, which would make
  every perf run and every CI test spawn peer toolchains.
- **No pinned peer toolchains and no new `*_pin.tl`.** Every `bin/cosmic --make
  fetch`, in every tree and every lane, resolves every pin; ~200 MB of toolchains on
  the trust root's fetch path for a report that never gates is not a trade this card
  makes.
- **No new `COSMIC_*` environment variable.** `_cli/env_vars.tl` is a ratcheted
  registry (`_build/env_vars_test.tl`); `--bin` and the existing `PERF_BIN` already
  select the binary.
- **No changes to `pr.yml` or `docs.yml`.** The gate lane is fenced (no network) and
  containerised (no node, no go), and docs.yml renders from the tree at push time
  with no release-time measurement, so neither can carry a measured table.
- **No new environment pins.** The `peers` job runs no build machinery, so the
  container/privilege/non-root-builder pins do not apply to it; that is exactly what
  the `UNCONTAINERISED` entry records.
- Never weaken a scenario or its `check()` to make a number look better.
