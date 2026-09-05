## Change

`bin/cosmic --make ci` on this repository spends ~140 s of wall time
in the coverage stage, which runs every `_work/*_test.tl` instrumented
(`o/coverage-summary.txt`: `wall: 139559ms  slowest:
.coverage/_work/gitverbs_test.tl (10752ms)`); sixteen agent slices
today each ran that gate six to ten times. Profile the suite and cut
it: measure per-file wall time from the coverage summary and the test
runner's `slowest:` lines, then for the ten slowest files find what
they wait on — each `init_state_repo` spawns `git init` plus a fetch
of the pinned runtime, `publish_race_test` and `storeref_test` create
several repositories, `gitverbs_test` runs whole verb pipelines per
case — and remove the wait: share one initialized template repository
per test file and copy it (`cp -r`, not `git init` plus `gitboard
init`), reuse one `cosmic` runtime per process, and split any file
that serialises many independent repositories. Report before/after
wall time in the PR; the target is the whole `--make ci` under 60 s
on this repository's CI runner with no test deleted or weakened.
