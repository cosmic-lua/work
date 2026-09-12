## Change

Speed up `_make.deps.closure` by projecting sparse reached-node sets through
a cached path-to-project-position index instead of scanning every project
file on every call. Preserve the existing scan for dense closures. Keep
`cosmic.graph.reach` as the graph algorithm and retain the existing
single-snapshot cache lifetime. No persistent cache, public API, C change,
runtime pin change, or graph-algorithm rewrite.

This is design only. Four dependency-ordered children cover contract tests,
an executable benchmark, the optimization, and independent verification.
The original unranked capture is attached last under G6, without moving any
existing work ahead of another item.

## Access

Implementation: cosmic-lua/cosmic, branch main. Board/evidence:
cosmic-lua/work. The orchestrator supplies this parent specification and
the relevant child specification to implementation agents.

## Evidence and choice

Source snapshot: cosmic b0ab4e8fe2bb798296e68e96ae640f82c8c03c5f.
`_make/deps.tl:111` (`cached_proj`) caches graph construction by the identity
pair `(proj, by_import)`. At `:180` (`local reached = graph.reach`), every
closure then scans `proj.files` to produce its answer in project order.
`cosmic/graph.tl:37` (`local function reach`) already visits only reachable
edges. `_make/project.tl:349` (`local function scan`) clears the import memo
and returns a new, sorted project snapshot. `_make/graph.tl:129`
(`local by_import = deps.index(proj)`) shares one index across all files;
`:139` and `:151` use closures for compile dependencies and runtime grants.
`_make/check.tl:103` consumes the same source closure. Too few dependencies
can produce a stale successful build or deny required reads; too many
broaden grants and rerun unrelated work.

Fresh scouting, macOS arm64, 2026-09-11 local date:

| Source-backed operation | Result |
|---|---:|
| Project files / total dependency occurrences | 954 / 17,661 |
| First all-file closure sweep, including graph construction/import reads | 274.014 ms CPU |
| Seven warm sweeps, same Project and index | 33.594–33.965 ms CPU |
| Separate graph.reach + reached-set count, all files | 4.393 ms CPU |
| Dependency count median / p90 / maximum | 9 / 38 / 206 |

An earlier run in this session measured 270.720 ms first sweep and
34.762–36.275 ms warm sweeps. These are diagnostics, not a harness A/B or
a promised speedup. The previous capture's ~0.5 seconds must not be
attributed entirely to warm closure conversion: the first sweep includes
graph construction and source import scanning. The new evidence establishes
repeatable projection overhead, not the old claimed 10% regression against
a different 944-file tree. The approximate 29 ms difference above is
headroom, not a predicted gain; these are separate measurements with
different result-consumption overhead.

Runtime: cosmic-lua 2026-09-10-851d5ec, cosmos 2026.09.06-e748d6a1e;
SHA256 10f66af3cfe6b55e3f97c058ddff5e6b0ba3faf6eef8c2462cb7372895e4e1c2.
The probe transpiled these current source modules with `tl.gen` and
installed preload loaders before requiring them: `_make.deps`,
`_make.project`, `_make.imports`, `_make.types`, `cosmic.graph`. Other
dependencies came from the identified runtime. It used `project.scan(root)`,
one `deps.index(proj)`, and timed a loop calling `deps.closure` for every
`proj.files` entry with `os.clock()`. The first and next seven sweeps were
reported separately. An adjacency map built with `deps.direct` outside
timing supplied the separate reach measurement. This is deliberately
labelled a hybrid diagnostic; acceptance uses actual built binaries.

Compared alternatives: ZIP bulk extraction ER8g_WTnv has a difficult
security/compatibility boundary, but fresh scouting does not establish
its old proposed 15–30% gain; its item records the probe. JSON's ASCII
span Ev3f_N6gu is a narrower C optimization. This item combines measurable
build overhead with dependency correctness and cache-ownership constraints.

## Fixed implementation contract

1. Cache one private snapshot record containing the graph and
   `position_by_path: {string: integer}`, with the existing Project/index
   identity key. Build both in the existing O(N + E) graph-construction
   pass; publish the cache only after both are complete. Positions are
   one-based ordinals in `proj.files`, not lexical ranks recomputed by
   sorting. Scanned projects have unique paths. No exported type or cast.
2. Compute `reached = graph.reach(snapshot.graph, file.path)` unchanged.
   Let `N = #proj.files` and `budget = N // 8`. Enumerate reached keys,
   exclude `file.path`, and look up their positions. Ignore keys absent
   from the position map, matching the old scan's intersection behavior.
3. Collect numeric positions only until their count exceeds `budget`.
   On that first excess, stop enumeration and use the original ordered
   `proj.files` scan against `reached`. Discard the partial positions;
   never return or merge a partial projection. This is the dense path.
4. Otherwise `table.sort(positions)` with its default numeric comparison,
   and append `proj.files[position]` into a NEW result array. Do not sort
   File objects with a Lua comparator. Empty results are fresh arrays too.
   N below 8 deliberately uses the scan for any nonempty closure.
5. The 1/8 budget is a conservative initial fixed policy, supported by
   the measured small closure sizes. It is not asserted optimal. Do not
   tune it during this item: if dense or whole-suite gates fail, reject
   this proposal or separately refine it with measurements. No host-based
   tuning, timing in production, or unbounded cache of closure results.
6. Cache misses remain mandatory for a different Project OR a different
   by_import table, including equal-content tables and A/B/A alternation.
   Existing snapshot immutability remains the prerequisite: callers must
   obtain a new scan/index after source edits, not mutate a live snapshot.
   The new index must be released with the old single cache slot.

Sparse projection costs O(K log K), with O(K) temporary positions, instead
of O(N) scanning. Dense projection stays O(N) after at most floor(N/8)+1
valid reached positions; graph traversal cost is unchanged. Extra retained
memory is O(N) for one snapshot. No all-pairs memoization or retained result
arrays. Result File objects must be the same objects as in `proj.files`.

## Verification specification

- Exact ordered arrays, not just membership: empty/singleton, chain,
  diamond, repeated imports, self-loop, multi-node cycle, disconnected
  nodes, external requires, absent root. Every result excludes the root.
- Use deliberately nonlexical project order in a hand-built valid
  snapshot fixture to detect accidental lexical sorting. Production
  scans are sorted, but closure preserves the supplied project order.
- Include `.lua` and `.d.tl` defining the same import; both source inputs
  survive, and `built_paths` still omits the declaration. Preserve original
  File reference identity and leave Project/index/graph inputs unmodified.
- For N=64 test 0, 1, 8, 9, and 63 reached dependencies: both sides of
  the sparse/dense boundary return the exact oracle array. Also N=0,1,7,8.
  Assert values rather than internal branch counters.
- Returned-array ownership: alter/remove/append entries in one returned
  array; the next answer is correct and independent. Do not mutate shared
  File records, which are intentionally the snapshot's objects.
- Cache lifecycle: same pair repeatedly; same project with a filtered
  new index; distinct project with the old index; two projects sharing
  relative filenames under different roots; A/B/A; edit and rescan with
  an added/removed edge. Each must match a fresh reference BFS.
- Deterministic small generated graphs with a fixed seed compare ordered
  closures for EVERY root to an independent direct-edge BFS plus project
  order scan. The test oracle must not call `graph.reach` or the new
  projection helper. Do not add a second production traversal.
- Preserve byte-identical `graph.project_mk` facts (normalize only the
  unavoidable root/binary path fields) and runtime grant lists. Extend
  build incremental integration coverage: changing a transitive module
  invalidates its dependants; an unrelated module does not; a `.d.tl`
  contract change invalidates the importer's check. Existing fence and
  closure suites must still pass.

## Performance and release acceptance

The benchmark child lands BEFORE the optimization. It provides checked
end-to-end scenarios through `cosmic.child`, with the chosen binary's
embedded build engine as subject, plus reproducible diagnostic commands
that split cold and warm costs. Keep the benchmark payload identical in
baseline and candidate. No fresh result files may overwrite the baseline.

Build the unmodified baseline after the benchmark commit, save its binary
at an immutable absolute path, and record source SHA/runtime pin/binary
SHA256, host, filesystem, environment, and fixture shape. Then build the
candidate. Set PERF_BIN to the binary under test for each run. Run each
explicit binary through `--make run _perf/run.tl --out <distinct file>`;
follow skills/optimize/measurement.md for tree-vs-embedded module identity.
Do not compare a stock release with a differently packaged local build.

Required acceptance: exact correctness, candidate `--make ci`, target
sparse repeated scenario improvement above measured noise, and full
`_perf/gate.tl compare BASE CURRENT SELFB` exit 0 with `perf-compare: PASS`.
Dense, first-sweep, and single-root costs must not show a reproducible
regression beyond the noise bar. For a <10% target result apply the skill's
interleaving/cross-session discipline; report uncertainty rather than a win.
Use separate filenames for baseline/current/selfcheck/retries. Do not
weaken scenarios, tests, gates, or thresholds. If the target fails to
improve or a real regression survives, do not ship the optimization;
record the failed hypothesis on this item. No fixed percentage promised.

Changes are confined to the cosmic build engine and its tests/benchmarks.
Normal cosmic packaging must include the changed `_make` source; inspect
the built artifact to establish that fact. No C release or cosmos pin bump
is needed. Findings and performance outputs stay on the board/local o/
directory, never in committed findings documents. Every new Teal file
stays below 500 lines; runner-mode tests use top-level `test_*` functions
and run through `--make test`, never bare test scripts.

## Historical capture

The original report compared a44b020d (944 files, ~0.470 s per all-file
sweep) to f8149470 (949 files, ~0.522 s). It recorded #1829's repair of
the much larger #1828 regression and identified per-call projection as
remaining work. These numbers are historical scouting across different
trees, not the baseline or acceptance threshold for this design.
