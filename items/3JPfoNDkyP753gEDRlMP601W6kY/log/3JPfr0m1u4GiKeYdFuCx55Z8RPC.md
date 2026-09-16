Measured 2026-09-16 in one orchestrator pass.

Eight worktrees were created (four builders, discarded when their base turned
out stale; four rebuilt; then four review checkouts). Each printed:

    runtime product download:
      "https://github.com/cosmic-lua/cosmic/releases/download/2026-09-07-2b2002d/cosmic-lua"
    runtime invocation:
      "<worktree>/o/.gitboard-runtime-<nonce>/cosmic"

— the same URL, the same pin, a fresh nonce directory each time. Wall time for
worktree creation was the dominant cost of the pass's setup phase.

A second, independent sighting from a reviewer working «Vi68_fUEj»: running
`bin/cosmic --make run _work/brieftmpl_gen.tl` inside a worktree the tooling
had just declared "already bootstrapped ... build: PASS (348 files, 1 binary)"
still printed "Downloading pinned cosmic...". Its words: "a small gap between
'bootstrapped' and 'every cache warm.'"

So the cost lands twice: once per worktree creation, and again inside a
worktree that has already been reported ready.