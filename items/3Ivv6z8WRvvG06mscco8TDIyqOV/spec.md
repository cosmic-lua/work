## Evidence

Surfaced 2026-09-06 while building board item `3IvOz0wC` (handle
«W3uo_Bvcn», "gcov: extract per-file line coverage from MODE=cov and
gate the test target on a committed floor"), out of scope for that
item (which explicitly excludes changing what the tests exercise).

**This item's original premise (the floor is committed at 590) is
stale.** `3IvOz0wC`'s own PR (merged as `b9246f8d`) carries a SECOND
commit, "line_coverage_floor: give lfetch.c headroom for run-to-run
variance," landed before this item was ever picked up, that already
lowers the floor and documents the same variance
(`tool/lua/line_coverage_floor.lua`, current at `origin/master`):

    ["tool/net/lfetch.c"] = { covered = 585, total = 873 },

with a comment already in place:

    -- lfetch.c's covered count varies by a few lines across otherwise
    -- identical serial runs (586-592 observed), most likely from
    -- timing-sensitive branches in the proxy/timeout tests exercising
    -- cosmo.Fetch/FetchStream; floored below the observed low end
    -- so run-to-run variance doesn't fail an unrelated PR; a real
    -- regression still has to drop coverage well past this margin.

A first builder attempt on this item (2026-09-06) ran `make MODE=cov
o/cov/tool/lua/test` 9 times and observed covered counts of 590 (x6),
586 (x2), 592 (x1) — every run at or above 585, the existing floor —
and reported the item as already resolved, recommending closure.

**That conclusion is falsified by evidence gathered independently,
the same day, on an unrelated PR's real CI run** — `cosmic-lua/cosmopolitan#388`
(a comment-only `BUILD.mk` change, nothing touching `lfetch.c` or its
tests), whose `build` check failed on `test_line_coverage.ok`:

    tool/net/lfetch.c: covered 582, floor 585
    make: *** [tool/lua/BUILD.mk:551: o/cov/tool/lua/test_line_coverage.ok] Error 1

(full job: https://github.com/cosmic-lua/cosmopolitan/actions/runs/34008013671/job/101418677688,
head `c7c27d1e65b0b100a5ffdf33996fde74c85841de`, run 2026-09-06T03:11Z)

So the true observed range is AT LEAST 582-592 (11 lines), not the
586-592 (7 lines) both this item's original Evidence and the existing
585 floor's own comment assumed — 585 is not "below the observed low
end" as its comment claims; it is IN the observed range, and a build
sitting on an entirely unrelated PR just failed because of it. The
`3IvOz0wC` fix narrowed the failure window but did not close it, and
this item's job — stabilize `lfetch.c`'s line coverage — is not done.

## Change

Investigate why `tool/net/lfetch.c`'s line coverage specifically
varies run-to-run under `MODE=cov`, by a WIDER margin than previously
measured (>= 582-592, 11 lines, not 586-592), and stabilize it for
real this time. Likely paths (not prescribed — the build should
measure and pick, per this repo's own measurement-first doctrine):

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

## Non-goals

- Not re-opening `3IvOz0wC`'s own scope (which files are instrumented,
  the collector's shape, the BUILD.mk wiring) — that item stands as
  built; this is a follow-on stabilization of one file's measurement.
- Not a general audit of test determinism across the suite — scoped to
  `lfetch.c`'s line coverage specifically, the one file this
  investigation found varying.
- Not assuming a fixed number of local reproduction runs proves
  stability — CI's own run environment demonstrably samples a wider
  variance than a local loop did; treat a local-only reproduction
  attempt that stays inside 586-592 as inconclusive, not as
  confirmation the floor holds.
