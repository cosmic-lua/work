Research slice, no PR: the deliverable is a recorded verdict on this
item (reproduced or not; if reproduced, which commit) plus follow-up
items for whatever answer that verdict points to.

1. Build `a5b36f4a` and current `origin/main` locally (per
   `skills/optimize/measurement.md`'s noise discipline — pinned CPU
   governor / quiet machine, not a shared CI runner) and run
   `bin/cosmic --make run _perf/run.tl --out <file>` for both, at
   least 3 times each, to get `embed_extract_tree`'s real distribution
   outside CI's noise. Use `_perf/gate.tl selfcheck` between two runs
   of the SAME binary first to confirm the local noise floor before
   trusting a cross-binary comparison.
2. If `embed_extract_tree` does not reproduce a >10% regression
   outside CI (i.e. it was CI-environment noise): record that verdict
   on this item with the commands and numbers that showed it, and
   stop — no follow-up item needed, P69O_Pzc2 unblocks as "noise,
   dismissed with evidence."
3. If it reproduces: `git bisect` the 8-commit window above using the
   same local `embed_extract_tree`-only measurement as the bisect
   script's pass/fail (a fixed number of iterations per commit, wide
   enough to clear the ±14.4% noise band observed in CI). Record the
   bisected commit and its plausible mechanism (read the diff) on
   this item.
4. Either way, file a follow-up item for whatever the verdict
   demands: a fix under `skills/optimize/SKILL.md` if a specific
   commit regressed `embed_extract_tree`, or nothing further if it
   was noise.
