Add checked end-to-end build-dependency benchmarks before optimizing
closure projection. Add `_perf/bench/deps_bench.tl` and a plain Lua child
driver `_perf/bench/testdata/deps_driver.lua`. The benchmark module uses
cosmic.child/fs and the existing `_perf.bench.binary`/perf_types helpers;
it does not call raw cosmo bindings or import `_make.deps` in the harness
process. The child deliberately exercises the chosen binary's embedded
private build engine, the actual subject of this item.
