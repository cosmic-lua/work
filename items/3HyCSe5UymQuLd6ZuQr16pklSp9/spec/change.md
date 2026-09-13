Publish, with every release, a ONE-METRIC peer table: the wall-clock cost of spawning
a hello-world script that prints `perf-hello`, measured for cosmic, CPython, Node and
Go on one machine in one job, by the harness that already measures
`startup_run_lua`.

**The task, identically for every row.** `_perf/bench/startup_bench.tl` spawns
` /hello.lua` through `cosmic.child.run`, asserts spawn + exit 0, trims
stdout, and its `check` requires stdout to equal exactly `perf-hello`; the harness
calibrates an iteration count so each sample lasts ≥ `DEFAULT_MIN_SAMPLE_SECS` and
takes `DEFAULT_SAMPLES` samples, reporting median wall ns/op with min/max/spread.
Every peer row runs that same shape: a script FILE that prints exactly `perf-hello`,
spawned through the same `child.run` capture path, timed by the same
`_perf.harness.run_scenario`, checked by the same exact-stdout rule. Not
`python3 -c pass` and not `node -e ''`: they produce no output, so the mandatory
`check()` every scenario must define (`_perf/perf_test.tl:61`) would have nothing to
verify, and they skip the script open+read that cosmic's row pays — a shorter task
for the peer than for cosmic is a table that flatters us.

The four rows, in this fixed order, which is the row order in every output:

| id | argv timed | artifact provenance |
|---|---|---|
| `cosmic-lua` | ` hello.lua` (`print("perf-hello")`) | prebuilt (`--bin`) |
| `cpython` | `python3 hello.py` (`print("perf-hello")`) | prebuilt, on PATH |
| `node` | `node hello.js` (`console.log("perf-hello")`) | prebuilt, on PATH |
| `go` | `./hello` | compiled at setup: `go build -o hello hello.go` |

Go's compile runs in setup, outside the timed region, because cosmic's binary is
prebuilt too — compilation is not part of the startup task. Each row records the
peer's version string, the artifact's path and byte size, its provenance, the exact
argv, and the probe argv that produced the version.

```facts
$ wc -l _perf/bench/startup_bench.tl
169 _perf/bench/startup_bench.tl
$ test -d _perf/peers && echo exists || echo absent
absent
$ ls _perf
baseline.tl
baseline_test.tl
bench
compare.tl
compare_test.tl
gate.tl
gate_test.tl
harness.tl
harness_test.tl
perf_test.tl
perf_types.tl
run.tl
run_test.tl
stats.tl
stats_test.tl
$ ls _perf/bench | wc -l
17
$ grep -n "^local DEFAULT_SAMPLES\|^local DEFAULT_MIN_SAMPLE_SECS" _perf/harness.tl
21:local DEFAULT_SAMPLES = 5
22:local DEFAULT_MIN_SAMPLE_SECS = 0.15
$ grep -n "s.check ~= nil" _perf/perf_test.tl
61:      assert(s.check ~= nil, name .. "/" .. s.name
$ grep -n "recursive = false" _perf/run.tl
184:    {glob = "*_bench.tl", recursive = false, sorted = true})
$ sed -n 205p cmd/cosmic/embed_gen.tl
    if f.path:sub(-3) == ".tl" and (f.kind == "module" or f.kind == "entry") then
$ grep -o peers .github/workflows/release.yml | wc -l
0
$ wc -l .github/workflows/release.yml _build/workflows_test.tl
  251 .github/workflows/release.yml
  278 _build/workflows_test.tl
  529 total
$ grep -o '\["[a-z]*\.yml:[a-z]*"\]' _build/workflows_test.tl
["pr.yml:smoke"]
["release.yml:release"]
```

Five new files under `_perf/peers/` (Teal, versioned, tested — the harness already
owns calibration, sampling, medians and the mandatory `check()`; workflow shell would
re-implement all of it untested), plus two edits. Keep each new file ≤ 200 lines,
well inside the 500-line cap.

1. **`_perf/peers/peers.tl`** — the registry and the measurement.
   - `record Peer` with `id`, `label`, `exe`, `probe_argv: {string}`, `script`,
     `source` (the hello text), `build_argv: {string} | nil`, and
     `run_argv: function(exe: string, target: string): {string}`.
   - `PEERS < const >: {Peer}` holding the four rows above in that order, and
     `EXPECT < const > = "perf-hello"`.
   - `check_stdout(out: string): boolean, string` — the exact-match rule, pure, so
     the check is unit-testable.
   - `probe(p: Peer): string | nil, string` — `child.run(p.probe_argv)`; a spawn
     failure or nonzero exit returns nil plus the reason; success returns the first
     line of stdout (falling back to stderr) trimmed.
   - `stage(dir: string, p: Peer): string | nil, string` — writes `p.source` to
     `dir/p.script`, runs `build_argv` in `dir` when present, and returns the path
     of the artifact to spawn.
   - `scenario(p: Peer, exe: string, target: string): pt.Scenario` — `fn` spawns
     `p.run_argv(exe, target)` via `child.run` and returns trimmed stdout; `check`
     is `check_stdout`. Same shape as `startup_bench.tl`'s `spawn_capture`.
   - `measure(opts: MeasureOptions): Report, string` — staging directory from
     `fs.temp_dir(fs.join(TEST_TMPDIR or TMPDIR or "/tmp", "perf-peers-XXXXXX"))`,
     removed with `fs.remove_all` when done. Per selected peer: probe, then either
     an `absent` row carrying the reason, or `harness.run_scenario` with the given
     `pt.Options` and a `measured` row carrying version, exe, `exe_bytes`
     (`fs.stat(...):size()`), provenance, argv, probe argv, `wall_ns`, `min_ns`,
     `max_ns`, `spread_pct`, `iterations`. cosmic's row takes its exe from
     `opts.bin` and its version from ` --version`; a cosmic row that fails to
     spawn or fails its check is an error return, not a row — a table without
     cosmic in it is not a table.
   - Local records `Row`, `Report {meta, task, rows}` and `PeerMeta` (timestamp,
     os, isa, nproc, samples, min_sample_secs, runner, cosmic_bin, cosmic_bin_sha
     via `hash.sha256_hex(fs.read(bin))` as `_perf/run.tl` does, cosmic_version).
     `runner` is `env.get("ImageOS") or "local"`.
2. **`_perf/peers/report.tl`** — pure rendering, no I/O:
   `format_markdown(rep: Report): string` (header naming the task and the one
   command that regenerates the table, the host/runner line, the table with columns
   `runtime | version | artifact | argv | ns/op | ±spread | iters` rendering ns
   through `harness.format_ns`, a fairness paragraph stating the same-task rule and
   Go's setup-time compile, a per-row `re-run` line, then the summary line LAST);
   `summary_line(rep): string` → `startup: cosmic-lua 1.23 ms | cpython 18.4 ms |
   node 31.2 ms | go 0.90 ms` (an absent peer renders `go absent`);
   `verdict(rep): string` → `peers: OK 4/4 measured`,
   `peers: OK 3/4 measured (absent: go)`, or `peers: FAIL ()`.
3. **`_perf/peers/run.tl`** — the one command, shaped like `_perf/baseline.tl`
   (shebang, `cosmic.flags` spec, `proc.is_main()` guard, module table, verdict line
   last). Flags: `--bin PATH` (default `PERF_BIN`, then `arg[-1]`, exactly
   `startup_bench.tl`'s `find_bin` precedence), `--out FILE` (peers.json via
   `cosmic.json`), `--md FILE` (peers.md), `--samples N`, `--min-secs S`,
   `--only ID` (exact id match; matching nothing prints
   `peers: FAIL (--only  matched nothing)` and exits 1, mirroring
   `_perf/run.tl`'s rule for the same flag). Creates parent directories for both
   outputs. Prints the markdown to stdout, then the verdict line; exits 0 on OK,
   1 on FAIL. It has no notion of a threshold and no comparison mode, so "never
   gates" is structural here rather than a workflow guard.
4. **`_perf/peers/peers_test.tl`** — no peer toolchain required: registry integrity
   (four peers, unique ids, cosmic first, fixed order, every `source` prints exactly
   `perf-hello`), `check_stdout` accepting `perf-hello` and rejecting `""`,
   `"hello"`, `"perf-hello extra"`, `stage` writing each script peer's file under
   `TEST_TMPDIR` and returning its path (no execution), and `probe` of
   `{"cosmic-no-such-peer-exe", "--version"}` returning nil with a reason.
5. **`_perf/peers/report_test.tl`** — pure: `format_markdown` over a literal 4-row
   `Report` (row order preserved, one row per peer), over a `Report` with an absent
   row, `summary_line`, `verdict` in all three cases, and that the markdown's LAST
   line is the summary line — the release notes read it with `tail -n1`.
6. **`.github/workflows/release.yml`** — one new job plus wiring, no other step
   touched:
   - a `peers` job: `needs: build`, `runs-on: ubuntu-latest`, **no container**,
     `timeout-minutes: 15`. Steps: `actions/checkout` and
     `actions/download-artifact` at the same pinned SHAs already used in this file,
     `name: cosmic-lua`, `path: dl/`; recover the binary with the same
     unzip-then-`find dl -type f -name cosmic` shape `pr.yml`'s `smoke` job uses,
     `chmod +x`; then ONE command, the downloaded artifact run directly with no
     build and no fetch:
     `./cosmic _perf/peers/run.tl --bin ./cosmic --out o/perf/peers.json --md o/perf/peers.md`;
     then `actions/upload-artifact` at the pinned SHA, `name: cosmic-peers`, with
     both files. A comment records why the lane is uncontainerised (the pinned
     buildpack-deps image has python3 — `pr.yml`'s `repro` job already relies on
     `python3 -m zipfile` — but no node and no go, while the runner image ships all
     three), that the versions are the runner image's and are recorded per row, and
     that the table reports standing and never gates.
   - the `release` job: `needs: [build, peers]`; locate `peers.json` and `peers.md`
     with the same `find artifacts -type f -name ...` pattern as the other assets,
     add both to the missing-asset guard, copy them into `release/`, attach both to
     `gh release create`, and extend `notes` with a third line,
     `"$(tail -n1 release/peers.md)"`.
7. **`_build/workflows_test.tl`** — add one entry to `UNCONTAINERISED` (line 103):
   `["release.yml:peers"] = "peer versions are the runner image's: the pinned
   container has no node and no go"`. Without it
   `test_every_build_job_is_containerised` fails on the new job. Headroom: 278/500.

Ratchets: if the coverage stage complains about the new `_perf/peers/**` rows, run
`o/bin/cosmic --make coverage --baseline` and commit the result; if the cast ratchet
complains, run `bin/cosmic --make run _build/casts.tl --baseline` and commit it. Those
regen commands are in scope; no gate is weakened any other way, and every `as` cast
carries its `-- cast: `.
