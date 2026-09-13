- **The accept/rework/bounce meanings do not move.** `check → land` is accept,
  `check → do` is rework, `→ plan` is reject-or-bounce. #1208 landed that split;
  this slice adds the in-window guard and the `cur.phase ~= "plan"` guard to the
  same branch and nothing else. Do not reintroduce the inference rule this issue
  originally proposed (classifying a `review → doing` transition by whether the
  issue later closed) — it is superseded by the phase split.
- **The pre-migration ambiguity is NOT fixed here.** `model.phase_of` maps the
  historical `plan:doing` → `do` and `plan:review` → `check`, so a
  pre-migration accept (`review → doing`, the same transition as a rework before
  #1208 landed 2026-08-16T19:04Z) still scores as a rework whenever the window
  reaches back past that instant. Fixing it needs a legacy-era discriminator on
  the event plus a fourth "unclassifiable" counter, which does not fit in
  `_work/stats.tl`'s 51 remaining lines beside this change. Follow-up slice. What
  this slice does buy: with the in-window guard, any window that opens after the
  migration instant is clean by construction.
- **No pagination.** `gh.list_issues` still requests one `per_page=100` page and
  never follows the Link header. `_work/github.tl` is 485/500 lines, so a
  Link-header follower plus its test cannot land there in this slice. Separate
  slice; do not touch `_work/github.tl`.
- **No change to `_work/model.tl`** — `PHASES`, `LIMITS`, `phase_of`,
  `LEGACY_PHASE`, `is_return` all stay exactly as they are. The window is a
  property of a report, not of the board model.
- **No new flags, no new verbs, no recommendations in the tool.** `stats` measures;
  the planner judges. `--days`' default stays 7 and its validation in
  `_work/board.tl` stays where it is.
- **No new `as` casts in `_work/stats.tl`**, and no new row for it in
  `_build/casts_baseline.tl`.
- **No change to the `work-stats: OK` / `work-stats: ERROR` verdict lines.**
- **No refactor of the module** — do not split the pure core out of
  `_work/stats.tl` while doing this, and do not rename `Stint`, `PhaseFlow`,
  `BackwardMoves`, `PickupLatency` or `FlowReport`.
