Investigate why `tool/net/lfetch.c`'s line coverage specifically
varies run-to-run under `MODE=cov`, by a WIDER margin than previously
measured (>= 582-592, 11 lines, not 586-592), and stabilize it for
real this time. No external precondition blocks starting immediately.
Likely paths (not prescribed — the build should measure and pick, per
this repo's own measurement-first doctrine), weighted by the CI-side
evidence above (four runs across two unrelated PRs, ALL landing on
exactly 582 — treat the first bullet below as the leading hypothesis
to confirm, not one alternative among several):

- First, test the CI-contention hypothesis directly before assuming
  pure randomness: reproduce under artificial CPU/IO contention
  locally (e.g. running `MODE=cov` alongside a CPU-saturating
  background load, or under `nice`/cgroup-limited CPU shares closer to
  a shared GitHub Actions runner) and see whether covered count
  reliably drops toward 582 under contention and stays near 590-592
  when quiet. This is cheaper than chasing the CI environment directly
  and would confirm or rule out the "reliably lower under contention"
  reading before deciding where the real fix belongs.
- Identify the specific non-deterministic branch(es) in
  `test_fetch_proxy.lua`/`test_fetchstream_edge.lua` (or elsewhere)
  that sometimes execute and sometimes don't, and either make the test
  deterministic (fixed timing, no real-network race) or accept the
  branch as intentionally environment-dependent and exclude it from
  the line-coverage floor's accounting for this file specifically.
  Re-run locally enough times (a local run of ~9 iterations landed in
  the 586-592 band without reaching 582 — CI's runner is evidently
  noisier; more iterations, or a change that samples under CPU/IO
  contention, is likelier to reproduce the 582 case than a quiet local
  loop) to have real confidence in whatever new floor or fix is
  proposed.
- Alternatively, if a few lines of inherent variance are accepted as
  genuinely unavoidable, lower `tool/lua/line_coverage_floor.lua`'s
  `lfetch.c` entry FURTHER — safely below 582, not 585 — and correct
  the existing comment's now-disproven "floored below the observed low
  end" claim to reflect the real, wider observed range and the CI run
  that established it.
