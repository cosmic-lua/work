## Change

`_perf/gate.tl`'s compare and selfcheck re-measure a flagged scenario
by re-running the bench, and that re-run spawns whatever binary the
environment names (`PERF_BIN`, and for gitboard's bench
`GITBOARD_PERF_BIN`) or the default `o/bin/gitboard`, then writes the
result over the input file it was given. Measured today: `gate.tl
selfcheck rel1.json rel2.json`, run without those variables after two
release-binary runs, overwrote both files with numbers from the
current build and stamped them `bin = o/bootstrap/cosmic`; the run
logs still held the release's 184 ms `show` while the files said 112.
Two changes. The re-measure must run the binary the results file
records (`meta.bin`, checked against `meta.bin_sha`) and refuse when
that file is missing or its hash differs, never the environment's or
a default; and it must write the re-measurement beside the input
(`<name>.remeasure.json`), never over it. A test in `_perf` covers a
results file whose recorded binary is absent (refusal names it) and
one whose hash differs (refusal names both). Measure first: reproduce
with two runs of one binary and a selfcheck under a different
`GITBOARD_PERF_BIN`, and paste the overwritten file's `meta.bin` in
the PR.
