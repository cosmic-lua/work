## Change

Add checked end-to-end build-dependency benchmarks before optimizing
closure projection. Add `_perf/bench/deps_bench.tl` and a plain Lua child
driver `_perf/bench/testdata/deps_driver.lua`. The benchmark module uses
cosmic.child/fs and the existing `_perf.bench.binary`/perf_types helpers;
it does not call raw cosmo bindings or import `_make.deps` in the harness
process. The child deliberately exercises the chosen binary's embedded
private build engine, the actual subject of this item.

## Access

cosmic-lua/cosmic (main), cosmic-lua/work. Requires the contract-test
child beneath this item to have landed. Parent W2CS_hqfO supplies the
algorithm, identity requirements, and acceptance bar.

## Implementation

Use `_perf/bench/startup_bench.tl:47` (`local function spawn_capture`)
and `_perf/bench/binary.tl:11` (`local function find_bin`) as precedents.
Declare `--- reads: _perf/bench/testdata/deps_driver.lua`; copy the driver
into the temporary scenario directory in setup, outside its project root.
Spawn an absolute selected
binary and absolute driver/root paths with cosmic.child, no shell. The
driver runs as plain Lua WITHOUT --make or a tree module override:
require('_make.project') and require('_make.deps') must resolve from that
binary. Benchmark the built candidate, not a launcher with mutable o/.

Create fixture sources during setup, outside measured fn, using generated
module names m0001 through mNNNN and deterministic LF source bytes:

- `build_deps_sparse_repeated`: N=1024; m0001 has no imports, every other
  module imports m0001. Child scans/indexes once, warms one all-file
  closure sweep, then performs 16 complete sweeps using that exact pair.
- `build_deps_dense_repeated`: N=256; m0001 has no imports, each later
  module imports its predecessor. Warm once, then perform 2 sweeps.
- `build_deps_first_sweep`: the sparse fixture, exactly one all-file sweep
  after a fresh scan/index in a fresh child process.
- `build_deps_single_root`: the sparse fixture, exactly one closure of
  m1024 after a fresh scan/index in a fresh child process.

The fixture Project may also contain the driver as a scanned .lua file:
put the driver OUTSIDE the project root (sibling under the scenario temp
directory), so the checked file count is exactly N. No host repository,
downloads, compiler invocation, timing-dependent inputs, or external
imports in fixture modules. Fixture roots must not inherit the cosmic
project's config; pass the isolated absolute root to project.scan.

Keep the last result array for each queried root. After the timed work
inside the driver, check every returned File.path and its position against
the analytic expected sequence: sparse root empty, other roots [m0001];
dense root i has m0001 through m(i-1). Reject missing, extra, duplicate,
unordered, or self entries. Print a small fixed success record only after
validation, including shape, N, sweeps, and total per-sweep memberships
(1023 sparse, 32640 dense, 1 single-root). The harness check asserts exact
record and successful child exit. Check failure must make the scenario fail.

The harness measures the whole child wall time INCLUDING scan, warmup,
and final validation. Name/report these as end-to-end amortized scenarios,
not pure warm function timings. In a diagnostic mode of the same driver,
print separate os.clock and monotonic wall intervals for scan/index,
first sweep, and seven warm sweeps; diagnostics are board evidence, not
extra benchmark rows or production telemetry. Diagnostic mode uses the
same calls but no optimized implementation or copied closure algorithm.

## Acceptance

Run `_perf/perf_test.tl` and targeted scenarios against an unmodified
build; smoke checks must detect deliberately corrupted fixture output
in a test, without leaving that corruption in the benchmark. Follow
parent Performance acceptance to save a full baseline AND A/A control
after this benchmark commit. Record runtime/source/binary hashes and
both timing boundaries. All baseline/candidate harness and driver files
must be byte-identical. New files each below 500 lines, <=400 changed
lines expected; split only fixture mechanics if the actual diff exceeds
that scope. No dependencies on another board item's future release.
